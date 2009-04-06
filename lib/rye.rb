
require 'rubygems' unless defined? Gem

require 'tempfile'
require 'net/ssh'
require 'net/scp'
require 'thread'
require 'highline'
require 'openssl'
require 'base64'

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
    # * +rap+ a Rye::Rap object
    def initialize(rap)
      @rap = rap
    end
    def message
      "(code: %s) %s" % [@rap.exit_code, @rap.stderr.join($/)]
    end
    def stderr; @rap.stderr if @rap; end
    def stdout; @rap.stdout if @rap; end
    def exit_code; @rap.exit_code if @rap; end
  end
  
  # Reload Rye dynamically. Useful with irb. 
  # NOTE: does not reload rye.rb. 
  def reload
    pat = File.join(File.dirname(__FILE__), 'rye')
    %w{key rap cmd box set}.each {|lib| load File.join(pat, "#{lib}.rb") }
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
        tmp = Rye::Key.from_file(file) 
        pk = tmp if tmp.private?
      rescue OpenSSL::PKey::PKeyError
      end
      !pk.nil?
    end
    files || []
  end
  
  


  # Add one or more private keys to the SSH Agent. 
  # * +keys+ one or more file paths to private keys used for passwordless logins. 
  def add_keys(*keys)
    keys = keys.flatten.compact || []
    return if keys.empty?
    Rye.shell("ssh-add", keys) if keys
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
    keystr = Rye.shell("ssh-add", '-l')
    return nil unless keystr
    keystr.collect do |key|
      key.split(/\s+/)
    end
  end
  
  def remote_host_keys(*hostnames)
    hostnames = hostnames.flatten.compact || []
    return if hostnames.empty?
    Rye.shell("ssh-keyscan", hostnames)
  end
  
  # Takes a command with arguments and returns it in a 
  # single String with escaped args and some other stuff. 
  # 
  # * +cmd+ The shell command name or absolute path.
  # * +args+ an Array of command arguments.  
  #
  # The command is searched for in the local PATH (where
  # Rye is running). An exception is raised if it's not
  # found. NOTE: Because this happens locally, you won't
  # want to use this method if the environment is quite
  # different from the remote machine it will be executed
  # on. 
  #
  # The command arguments are passed through Escape.shell_command
  # (that means you can't use environment variables or asterisks).
  #
  def prepare_command(cmd, *args)
    args &&= [args].flatten.compact
    cmd = Rye.which(cmd)
    raise CommandNotFound.new(cmd || 'nil') unless cmd
    # Symbols to switches. :l -> -l, :help -> --help
    args.collect! do |a|
      a = "-#{a}" if a.is_a?(Symbol) && a.to_s.size == 1
      a = "--#{a}" if a.is_a?(Symbol)
      a
    end
    Rye.escape(@safe, cmd, *args)
  end
  
  # An all ruby implementation of unix "which" command. 
  #
  # * +executable+ the name of the executable
  # 
  # Returns the absolute path if found in PATH otherwise nil.
  def which(executable)
    return unless executable.is_a?(String)
    #return executable if File.exists?(executable) # SHOULD WORK, MUST TEST
    shortname = File.basename(executable)
    dir = Rye.sysinfo.paths.select do |path|    # dir contains all of the 
      next unless File.exists? path             # occurrences of shortname  
      Dir.new(path).entries.member?(shortname)  # found in the paths. 
    end
    File.join(dir.first, shortname) unless dir.empty? # Return just the first
  end
  
  # Execute a local system command (via the shell, not SSH)
  #  
  # * +cmd+ the executable path (relative or absolute)
  # * +args+ Array of arguments to be sent to the command. Each element
  # is one argument:. i.e. <tt>['-l', 'some/path']</tt>
  #
  # NOTE: shell is a bit paranoid so it escapes every argument. This means
  # you can only use literal values. That means no asterisks too. 
  #
  # Returns a Rye::Rap object containing the 
  def shell(cmd, *args)
    args = args.flatten.compact
    cmd = cmd.to_s if cmd.is_a?(Symbol)
    # TODO: allow stdin to be sent to the cmd
    tf = Tempfile.new(cmd)
    cmd = Rye.prepare_command(cmd, args)
    cmd << " 2>#{tf.path}" # Redirect STDERR to file. Works in DOS too.
    # Deal with STDOUT
    handle = IO.popen(cmd, "r")
    stdout = handle.read.chomp
    handle.close
    # Then STDERR
    stderr = File.exists?(tf.path) ? File.read(tf.path) : ''
    tf.delete
    # Create the response object
    rap = Rye::Rap.new(self)
    rap.add_stdout(stdout || '')
    rap.add_stderr(stderr || '')
    rap.exit_code = $?
    rap
  end
  
  # Creates a string from +cmd+ and +args+. If +safe+ is true
  # it will send them through Escape.shell_command otherwise 
  # it will return them joined by a space character. 
  def escape(safe, cmd, *args)
    args = args.flatten.compact || []
    safe ? Escape.shell_command(cmd, *args).to_s : [cmd, args].flatten.compact.join(' ')
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
    lines = Rye.shell("ssh-agent", '-s') || []
    lines.each do |line|
      next unless line.index("echo").nil?
      line = line.slice(0..(line.index(';')-1))
      key, value = line.chomp.split( /=/ )
      @@agent_env[key] = value
    end
    ENV["SSH_AUTH_SOCK"] = @@agent_env["SSH_AUTH_SOCK"]
    ENV["SSH_AGENT_PID"] = @@agent_env["SSH_AGENT_PID"]
    
    Rye.shell("ssh-add") # Add the user's default keys
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
    Rye.shell("ssh-agent", '-k') || []
    #Rye.shell("kill", ['-9', pid]) if pid
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



  