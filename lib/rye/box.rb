

module Rye
  
  
  # = Rye::Box
  #
  # The Rye::Box class represents a machine. All system
  # commands are made through this class.
  #
  #     rbox = Rye::Box.new('filibuster')
  #     rbox.hostname   # => filibuster
  #     rbox.uname      # => FreeBSD
  #     rbox.uptime     # => 20:53  up 1 day,  1:52, 4 users
  #
  # You can also run local commands through SSH
  #
  #     rbox = Rye::Box.new('localhost') 
  #     rbox.hostname   # => localhost
  #     rbox.uname      # => Darwin
  #
  class Box 
    include Rye::Cmd
    
      # An instance of Net::SSH::Connection::Session
    attr_reader :ssh
    
    attr_reader :debug
    attr_reader :error
    
    attr_accessor :host
    
    attr_accessor :safe
    attr_accessor :opts

      # The most recent value from Box.cd or Box.[]
    attr_reader :current_working_directory
    
    # * +host+ The hostname to connect to. The default is localhost.
    # * +opts+ a hash of optional arguments.
    #
    # The +opts+ hash excepts the following keys:
    #
    # * :user => the username to connect as. Default: the current user. 
    # * :safe => should Rye be safe? Default: true
    # * :keys => one or more private key file paths (passwordless login)
    # * :password => the user's password (ignored if there's a valid private key)
    # * :debug => an IO object to print Rye::Box debugging info to. Default: nil
    # * :error => an IO object to print Rye::Box errors to. Default: STDERR
    #
    # NOTE: +opts+ can also contain any parameter supported by 
    # Net::SSH.start that is not already mentioned above.
    #
    def initialize(host='localhost', opts={})
      
      # These opts are use by Rye::Box and also passed to Net::SSH
      @opts = {
        :user => Rye.sysinfo.user, 
        :safe => true,
        :port => 22,
        :keys => [],
        :debug => nil,
        :error => STDERR,
      }.merge(opts)
      
      # See Net::SSH.start
      @opts[:paranoid] = true unless @opts[:safe] == false
      
      # Close the SSH session before Ruby exits. This will do nothing
      # if disconnect has already been called explicitly. 
      at_exit {
        self.disconnect
      }
            
      @host = host
      
      @safe = @opts.delete(:safe)
      @debug = @opts.delete(:debug)
      @error = @opts.delete(:error)
      
      add_keys(@opts[:keys])
      
      # We don't want Net::SSH to handle the keypairs. This may change
      # but for we're letting ssh-agent do it. 
      @opts.delete(:keys)
      
    end
    
     
    # Returns an Array of system commands available over SSH
    def can
      Rye::Cmd.instance_methods
    end
    alias :commands :can
    alias :cmds :can
    
    def copy_to(*boxes)
      p boxes
      
      @scp = Net::SCP.start(@host, @opts[:user], @opts || {}) 
      #@ssh.is_a?(Net::SSH::Connection::Session) && !@ssh.closed?
#      p @scp
    end
    
      
    # Change the current working directory (sort of). 
    #
    # I haven't been able to wrangle Net::SSH to do my bidding. 
    # "My bidding" in this case, is maintaining an open channel between commands.
    # I'm using Net::SSH::Connection::Session#exec for all commands
    # which is like a funky helper method that opens a new channel
    # each time it's called. This seems to be okay for one-off 
    # commands but changing the directory only works for the channel
    # it's executed in. The next time exec is called, there's a
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
    
    # Open an SSH session with +@host+. This called automatically
    # when you the first comamnd is run if it's not already connected.
    # Raises a Rye::NoHost exception if +@host+ is not specified.
    def connect
      raise Rye::NoHost unless @host
      disconnect if @ssh 
      debug "Opening connection to #{@host}"
      @ssh = Net::SSH.start(@host, @opts[:user], @opts || {}) 
      @ssh.is_a?(Net::SSH::Connection::Session) && !@ssh.closed?
      self
    end

    # Close the SSH session  with +@host+. This is called 
    # automatically at exit if the connection is open. 
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
      Rye.add_keys(additional_keys)
      self
    end
    alias :add_key :add_keys
    
    # Add an environment variable. +n+ and +v+ are the name and value.
    # Returns the instance of Rye::Box
    def add_env(n, v)
      debug "Added env: #{n}=#{v}"
      (@current_environment_variables ||= {})[n] = v
      self
    end
    alias :add_environment_variable :add_env
    
    # See Rye.keys
    def keys
      Rye.keys
    end
    
    # Returns +@host+
    def to_s
      @host
    end
    
    def inspect
      %q{#<%s:%s cwd=%s env=%s safe=%s opts=%s>} % 
      [self.class.to_s, self.host, 
       @current_working_directory, (@current_environment_variables || '').inspect,
       self.safe, self.opts.inspect]
    end
    
    # Compares itself with the +other+ box. If the hostnames
    # are the same, this will return true. Otherwise false. 
    def ==(other)
      @host == other.host
    end
    
    def scp(*args)
      args = [args].flatten.compact || []
      other = args.pop
      p other
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
    def Box.prepare_command(cmd, *args)
      args &&= [args].flatten.compact
      cmd = Rye::Box.which(cmd)
      raise CommandNotFound.new(cmd || 'nil') unless cmd
      Rye::Box.escape(@safe, cmd, *args)
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
    
    # Creates a string from +cmd+ and +args+. If +safe+ is true
    # it will send them through Escape.shell_command otherwise 
    # it will return them joined by a space character. 
    def Box.escape(safe, cmd, *args)
      args = args.flatten.compact || []
      safe ? Escape.shell_command(cmd, *args).to_s : [cmd, args].flatten.compact.join(' ')
    end
    
    private
      
      
      def debug(msg); @debug.puts msg if @debug; end
      def error(msg); @error.puts msg if @error; end

      
      # Add the current environment variables to the beginning of +cmd+
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
      # This method will try to connect to the host automatically
      # but if it fails it will raise a Rye::NotConnected exception. 
      # 
      def run_command(*args)
        connect if !@ssh || @ssh.closed?
        args = args.flatten.compact
        args = args.first.split(/\s+/) if args.size == 1
        cmd = args.shift
        
        raise Rye::NotConnected, @host unless @ssh && !@ssh.closed?

        cmd_clean = Rye::Box.escape(@safe, cmd, args)
        cmd_clean = prepend_env(cmd_clean)
        if @current_working_directory
          cwd = Rye::Box.escape(@safe, 'cd', @current_working_directory)
          cmd_clean = [cwd, cmd_clean].join(' && ')
        end
        debug "Executing: %s" % cmd_clean
        stdout, stderr, ecode, esignal = net_ssh_exec! cmd_clean
        rap = Rye::Rap.new(self)
        rap.add_stdout(stdout || '')
        rap.add_stderr(stderr || '')
        rap.exit_code = ecode
        rap.exit_signal = esignal
        rap.cmd = cmd
        
        raise Rye::CommandError.new(rap) if ecode > 0
        
        rap
      end
      alias :cmd :run_command
      
      # Executes +command+ via SSH
      # Returns an Array with 4 elements: [stdout, stderr, exit code, exit signal]
      def net_ssh_exec!(command)
        block ||= Proc.new do |channel, type, data|
          channel[:stdout] ||= ""
          channel[:stderr] ||= ""
          channel[:stdout] << data if type == :stdout
          channel[:stderr] << data if type == :stderr
          channel.on_request("exit-status") do |ch, data|
            # Anything greater than 0 is an error
            channel[:exit_code] = data.read_long
          end
          channel.on_request("exit-signal") do |ch, data|
            # This should be the POSIX SIGNAL that ended the process
            channel[:exit_signal] = data.read_long
          end
          # For long-running commands like top, this will print the output.
          # It cool, but we'd also need to enable STDIN to interact with 
          # command. 
          #channel.on_data do |ch, data|
          #  puts "got stdout: #{data}"
          #  channel.send_data "something for stdin\n"
          #end
        end
        
        channel = @ssh.exec(command, &block)
        channel.wait  # block until we get a response
        
        channel[:exit_code] ||= 0
        channel[:exit_code] &&= channel[:exit_code].to_i
        
        channel[:stderr].gsub!(/bash: line \d+:\s+/, '') if channel[:stderr]
        
        [channel[:stdout], channel[:stderr], channel[:exit_code], channel[:exit_signal]]
      end
      
      

  end
end


