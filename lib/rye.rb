
require 'rubygems' unless defined? Gem

require 'net/ssh'
require 'net/scp'
require 'thread'
require 'highline'
require 'openssl'

require 'esc'
require 'sys'

# = Rye
#
# Safely run remote commands via SSH in Ruby.
#
# Rye is similar to Rush[http://rush.heroku.com] but everything 
# happens over SSH (no HTTP daemon) and the default settings are
# less dangerous (for safety). For example, file globs are  
# disabled so unless otherwise specified, you can't do this: 
# <tt>rbox.rm('/etc/**/*')</tt>. 
#
# * See +bin/try+ for a bunch of working examples. 
# * See Rye::Box#initialize for info about disabling safe-mode.
#
module Rye
  extend self

  unless defined?(SYSINFO)
    VERSION = 0.3.freeze
    SYSINFO = SystemInfo.new.freeze
  end
  
  @@agent_env = Hash.new  # holds ssh-agent env vars
  @@mutex = Mutex.new     # for synchronizing threads
  
  # Accessor for an instance of SystemInfo
  def Rye.sysinfo; SYSINFO; end
  
  # Accessor for an instance of SystemInfo
  def sysinfo; SYSINFO;  end
  
  class NoBoxes < RuntimeError; end
  class NoHost < RuntimeError; end
  class NotConnected < RuntimeError; end
  class CommandNotFound < RuntimeError; end
  class CommandError < RuntimeError
    attr_reader :rap
    # * +rap+ a Rye::Rap object
    def initialize(rap)
      @rap = rap
    end
    def message
      "(code: %s) %s" % [@rap.exit_code, @rap.stderr.join($/)]
    end
  end
  # Reload Rye dynamically. Useful with irb. 
  # NOTE: does not reload rye.rb. 
  def reload
    pat = File.join(File.dirname(__FILE__), 'rye')
    %w{rap cmd box set}.each {|lib| load File.join(pat, "#{lib}.rb") }
  end
  
  def mutex
    @@mutex
  end
  
  # Looks for private keys in +path+ and returns and Array of paths
  # to the files it fines. Raises an Exception if path does not exist.
  # If path is a file rather than a directory, it will check whether
  # that single file is a private key.
  def find_private_keys(path)
    raise "#{path} does not exist" unless File.exists?(path || '')
    if File.directory?(path)
      files = Dir.entries(path).collect { |file| File.join(path, file) }
    else
      files = [path]
    end
    
    files = files.select do |file|
      next if File.directory?(file)
      pk = nil
      begin
        pk = load_private_key(file) 
      rescue OpenSSL::PKey::PKeyError
      end
      !pk.nil?
    end
    files || []
  end
  
  
  # Loads a private key from a file. It will correctly determine
  # whether the file describes an RSA or DSA key, and will load it
  # appropriately. The new key is returned. If the key itself is
  # encrypted (requiring a passphrase to use), the user will be
  # prompted to enter their password.
  # NOTE: Taken from Net::SSH
  def load_private_key( filename )
    file = File.read( filename )

    if file.match( /-----BEGIN DSA PRIVATE KEY-----/ )
      key_type = OpenSSL::PKey::DSA
    elsif file.match( /-----BEGIN RSA PRIVATE KEY-----/ )
      key_type = OpenSSL::PKey::RSA
    elsif file.match( /-----BEGIN (.*) PRIVATE KEY-----/ )
      raise OpenSSL::PKey::PKeyError, "not a supported key type '#{$1}'"
    else
      raise OpenSSL::PKey::PKeyError, "not a private key (#{filename})"
    end

    encrypted_key = file.match( /ENCRYPTED/ )
    password = encrypted_key ? 'nil' : nil
    tries = 0

    begin
      return key_type.new( file, password )
    rescue OpenSSL::PKey::RSAError, OpenSSL::PKey::DSAError => e
      if encrypted_key && @prompter
        tries += 1
        if tries <= 3
          password = @prompter.password(
            "Enter password for #{filename}: " )
          retry
        else
          raise
        end
      else
        raise
      end
    end
  end

  # Loads a public key from a file. It will correctly determine whether
  # the file describes an RSA or DSA key, and will load it
  # appropriately. The new public key is returned.
  # NOTE: Taken from Net::SSH
  def load_public_key( filename )
    data = File.open( filename ) { |file| file.read }
    type, blob = data.split( / / )

    blob = Base64.decode64( blob )
    reader = @buffers.reader( blob )
    key = reader.read_key or
      raise OpenSSL::PKey::PKeyError,
        "not a public key #{filename.inspect}"
    return key
  end


  # Add one or more private keys to the SSH Agent. 
  # * +keys+ one or more file paths to private keys used for passwordless logins. 
  def add_keys(*keys)
    keys = [keys].flatten.compact || []
    return if keys.empty?
    Rye::Box.shell("ssh-add", keys) if keys
    keys
  end
  
  # Returns an Array of info about the currently available
  # SSH keys, as provided by the SSH Agent. See
  # Rye.start_sshagent_environment
  #
  # Returns: [[bits, finger-print, file-path], ...]
  #
  def keys
    # 2048 76:cb:d7:82:90:92:ad:75:3d:68:6c:a9:21:ca:7b:7f /Users/rye/.ssh/id_rsa (RSA)
    # 2048 7b:a6:ba:55:b1:10:1d:91:9f:73:3a:aa:0c:d4:88:0e /Users/rye/.ssh/id_dsa (DSA)
    keystr = Rye::Box.shell("ssh-add", '-l')
    return nil unless keystr
    keystr.split($/).collect do |key|
      key.split(/\s+/)
    end
  end
  
  private 
  
  # Start the SSH Agent locally. This is important
  # primarily because Rye relies on it for SSH key
  # management. If the agent doesn't start then 
  # passwordless logins won't work. 
  #
  # This method starts an instances of ssh-agent
  # and sets the appropriate environment so all
  # local commands run by Rye will have access be aware
  # of this instance of the agent too. 
  #
  # The equivalent commands on the shell are:
  # 
  #     $ ssh-agent -s
  #     SSH_AUTH_SOCK=/tmp/ssh-tGvaOXIXSr/agent.12951; export SSH_AUTH_SOCK;
  #     SSH_AGENT_PID=12952; export SSH_AGENT_PID;
  #     $ SSH_AUTH_SOCK=/tmp/ssh-tGvaOXIXSr/agent.12951; export SSH_AUTH_SOCK;
  #     $ SSH_AGENT_PID=12952; export SSH_AGENT_PID;
  #
  # NOTE: The OpenSSL library (The C one, not the Ruby one) 
  # must be installed for this to work.
  # 
  def start_sshagent_environment
    return if @@agent_env["SSH_AGENT_PID"]
    lines = Rye::Box.shell("ssh-agent", '-s') || ''
    lines.split($/).each do |line|
      next unless line.index("echo").nil?
      line = line.slice(0..(line.index(';')-1))
      key, value = line.chomp.split( /=/ )
      @@agent_env[key] = value
    end
    ENV["SSH_AUTH_SOCK"] = @@agent_env["SSH_AUTH_SOCK"]
    ENV["SSH_AGENT_PID"] = @@agent_env["SSH_AGENT_PID"]
    
    Rye::Box.shell("ssh-add") # Add the user's default keys
    nil
  end
  
  # Kill the local instance of the SSH Agent we started.
  #
  # Calls this command via the local shell:
  #
  #     $ ssh-agent -k
  #
  # which uses the SSH_AUTH_SOCK and SSH_AGENT_PID environment variables 
  # to determine which ssh-agent to kill. 
  #
  def end_sshagent_environment
    pid = @@agent_env["SSH_AGENT_PID"]
    Rye::Box.shell("ssh-agent", '-k') || ''
    #Rye::Box.shell("kill", ['-9', pid]) if pid
    @@agent_env.clear
    nil
  end
  
  Rye.reload
  
  begin
    @@mutex.synchronize {                   # One thread only
      start_sshagent_environment            # Run this now
      at_exit { end_sshagent_environment }  # Run this before Ruby exits
    }
    
  rescue => ex
    STDERR.puts "Error initializing the SSH Agent (is OpenSSL installed?):"
    STDERR.puts ex.message
    exit 1
  end
  
end



  