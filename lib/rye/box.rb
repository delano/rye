

module Rye
  
  
  # = Rye::Box
  #
  # The Rye::Box class represents a machine. All system
  # commands are made through this class.
  #
  #     rbox = Rye::Box.new('filibuster')
  #     rbox.hostname   # => filibuster
  #
  # You can also run local commands through SSH
  #
  #     rbox = Rye::Box.new('localhost') 
  #     rbox.hostname   # => localhost
  #
  #     rbox = Rye::Box.new
  #     rbox.hostname   # => localhost
  #
  class Box 
    include Rye::Cmd
    
    @@agent_env ||= Hash.new  # holds ssh-agent env vars
    
      # An instance of Net::SSH::Connection::Session
    attr_reader :ssh
    
    attr_reader :debug
    attr_reader :error
    
    attr_accessor :host
    attr_accessor :user
    
    # * +host+ The hostname to connect to. The default is localhost.
    # * +opts+ a hash of optional arguments in the following format:
    #
    # * :user => the username to connect as. Default: the current user. 
    # * :keypairs => one or more private key file paths (passwordless login)
    # * :debug => an IO object to print Rye::Box debugging info to
    # * :error => an IO object to print Rye::Box errors to. Default: STDERR
    def initialize(host='localhost', opts={})
      
      opts = {
        :user => Rye.sysinfo.user, 
        :keypairs => [],
        :debug => nil,
        :error => STDERR,
      }.merge(opts)
      
      # TODO: move to Rye
      @mutex = Mutex.new
      @mutex.synchronize { Box.start_sshagent_environment }   # One thread only
      
      at_exit {
        self.disconnect
        Box.end_sshagent_environment
      }
      
      @host = host
      @user = opts[:user]
      @debug = opts[:debug]
      @error = opts[:error]
      add_keys(opts[:keypaths])
    end
    
     
    # Returns an Array of system commands available over SSH
    def can
      Rye::Cmd.instance_methods
    end
    alias :commands :can
    alias :cmds :can
    
    # Change the current working directory (sort of). 
    #
    # I haven't been able to wrangle Net::SSH to do my bidding. 
    # "My bidding" in this case, is maintaining an open channel between commands.
    # I'm using Net::SSH::Connection::Session#exec! for all commands
    # which is like a funky helper method that opens a new channel
    # each time it's called. This seems to be okay for one-off 
    # commands but changing the directory only works for the channel
    # it's executed in. The next time exec! is called, there's a
    # new channel which is back in the default (home) directory. 
    #
    # Long story short, the work around is to maintain the current
    # directory locally and send it with each command. 
    # 
    #     rbox.pwd              # => /home/rye ($ pwd )
    #     rbox['/usr/bin'].pwd  # => /usr/bin  ($ cd /usr/bin && pwd)
    #     rbox.pwd              # => /usr/bin  ($ cd /usr/bin && pwd)
    #
    def [](key=nil)
      @current_working_directory = key
      self
    end
    alias :cd :'[]'
    
    
    # Add an environment variable to the command
    def add_env(n, v)
      debug "Added env: #{n}=#{v}"
      (@current_environment_variables ||= {})[n] = v
      self
    end
    
    # Open an SSH session with +@host+.  
    # Raises a Rye::NoHost exception if +@host+ is not specified.
    def connect
      raise Rye::NoHost unless @host
      disconnect if @ssh 
      debug "Opening connection to #{@host}"
      @ssh = Net::SSH.start(@host, @user) 
      @ssh.is_a?(Net::SSH::Connection::Session) && !@ssh.closed?
      self
    end

    # Close the SSH session  with +@host+
    def disconnect
      return unless @ssh && !@ssh.closed?
      @ssh.loop(0.1) { @ssh.busy? }
      debug "Closing connection to #{@ssh.host}"
      @ssh.close
    end
    
    # Add one or more private keys to the SSH Agent. 
    # * +additional_keys+ is a list of file paths to private keys
    # Returns the instance of Box
    def add_keys(*additional_keys)
      additional_keys = [additional_keys].flatten.compact || []
      Rye::Box.shell("ssh-add", additional_keys) if additional_keys
      Rye::Box.shell("ssh-add") # Add the user's default keys
      self
    end
    alias :add_key :add_keys
    
    # Returns an Array of info about the currently available
    # SSH keys, as provided by the SSH Agent. See
    # Box.start_sshagent_environment
    #
    # Returns: [[bits, finger-print, file-path], ...]
    def keys
      # 2048 76:cb:d7:82:90:92:ad:75:3d:68:6c:a9:21:ca:7b:7f /Users/rye/.ssh/id_rsa (RSA)
      # 2048 7b:a6:ba:55:b1:10:1d:91:9f:73:3a:aa:0c:d4:88:0e /Users/rye/.ssh/id_dsa (DSA)
      keystr = Rye::Box.shell("ssh-add", '-l')
      return nil unless keystr
      keystr.split($/).collect do |key|
        key.split(/\s+/)
      end
    end
    
    # Takes a command with arguments and returns it in a 
    # single String with escaped args and some other stuff. 
    # 
    # * +args+ An Array. The first element must be the 
    # command name, the rest are its aruments. 
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
    def Box.prepare_command(*args)
      args &&= [args].flatten.compact
      cmd = args.shift
      cmd = Rye::Box.which(cmd)
      raise CommandNotFound.new(cmd || 'nil') unless cmd
      Escape.shell_command([cmd, *args]).to_s
    end
    
    # An all ruby implementation of unix "which" command. 
    #
    # * +executable+ the name of the executable
    # 
    # Returns the absolute path if found in PATH otherwise nil.
    def Box.which(executable)
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
    def Box.shell(cmd, args=[])
      # TODO: allow stdin to be send to cmd
      cmd = Box.prepare_command(cmd, args)
      cmd << " 2>&1" # Redirect STDERR to STDOUT. Works in DOS also.
      handle = IO.popen(cmd, "r")
      output = handle.read.chomp
      handle.close
      output
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
      def Box.start_sshagent_environment
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
      def Box.end_sshagent_environment
        pid = @@agent_env["SSH_AGENT_PID"]
        Rye::Box.shell("ssh-agent", '-k') || ''
        #Rye::Box.shell("kill", ['-9', pid]) if pid
        @@agent_env.clear
        nil
      end
      
      
      def debug(msg); @debug.puts msg if @debug; end
      def error(msg); @error.puts msg if @error; end

      
      def prepend_env(cmd)
        return cmd unless @current_environment_variables.is_a?(Hash)
        env = ''
        @current_environment_variables.each_pair do |n,v|
          env << "export #{n}=#{Escape.shell_single_word(v)}; "
        end
        [env, cmd].join(' ')
      end
      
      # Execute a command over SSH
      #
      # * +args+ is a command name and list of arguments. 
      # The command name is the literal name of the command
      # that will be executed in the remote shell. The arguments
      # will be thoroughly escaped and passed to the command.
      #
      #     rbox = Rye::Box.new
      #     rbox.ls '-l', 'arg1', 'arg2'
      #
      # is equivalent to
      #
      #     $ ls -l 'arg1' 'arg2'
      #
      def command(*args)
        connect if !@ssh || @ssh.closed?
        raise Rye::NotConnected, @host unless @ssh && !@ssh.closed?
        args = args.first.split(/\s+/) if args.size == 1
        cmd, args = args.flatten.compact
        cmd_clean = Escape.shell_command(cmd, *args).to_s
        cmd_clean = prepend_env(cmd_clean)
        cmd_clean << " 2>&1" # STDERR into STDOUT. Works in DOS also.
        if @current_working_directory
          cwd = Escape.shell_command('cd', @current_working_directory)
          cmd_clean = [cwd, cmd_clean].join('; ')
        end
        debug "Executing: %s" % cmd_clean
        output = @ssh.exec! cmd_clean
        Rye::Rap.new(self, (output || '').split($/))
      end
      alias :cmd :command
      

  end
end


