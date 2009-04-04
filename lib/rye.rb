
require 'rubygems' unless defined? Gem

require 'net/ssh'
require 'thread'
require 'highline'
require 'esc'
require 'sys'

# = Rye
#
# Run system commands via SSH locally and remotely in a Ruby way.
#
# Rye is similar to Rush[http://rush.heroku.com] but everything 
# happens over SSH (no HTTP daemon) and the default settings are
# less powerful (for safety). For example, file globs are disabled 
# so unless you specify otherwise, you can't do this: 
# <tt>rbox.rm('/etc/**/*')</tt>. 
#
# * See +bin/try+ for a bunch of working examples. 
# * See Rye::Box#initialize for info about changing the defaults.
#
module Rye
  extend self

  unless defined?(SYSINFO)
    VERSION = 0.2.freeze
    SYSINFO = SystemInfo.new.freeze
  end
  
  @@agent_env = Hash.new  # holds ssh-agent env vars
  @@mutex = Mutex.new     # for synchronizing threads
  
  def Rye.sysinfo; SYSINFO; end
  def sysinfo; SYSINFO;  end
  
  class CommandNotFound < RuntimeError; end
  class NoBoxes < RuntimeError; end
  class NoHost < RuntimeError; end
  class NotConnected < RuntimeError; end
  
  # Reload Rye dynamically. Useful with irb. 
  # NOTE: does not reload rye.rb. 
  def reload
    pat = File.join(File.dirname(__FILE__), 'rye')
    %w{rap cmd box set}.each {|lib| load File.join(pat, "#{lib}.rb") }
  end
  
  def mutex
    @@mutex
  end
  
  def add_keys(keys)
    keys = [keys].flatten.compact || []
    return if keys.empty?
    Rye::Box.shell("ssh-add", keys) if keys
    Rye::Box.shell("ssh-add") # Add the user's default keys
    keys
  end
  
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



  