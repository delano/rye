

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
  #     rbox.uname(:a)  # => Darwin vanya 9.6.0 ...
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
      
      debug @opts.inspect
            
      add_keys(@opts[:keys])
      
      # We don't want Net::SSH to handle the keypairs. This may change
      # but for we're letting ssh-agent do it. 
      #@opts.delete(:keys)
      

      debug "ssh-agent info: #{Rye.sshagent_info.inspect}"
      
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
#    alias :cd :'[]'  # fix for jruby
    def cd(key=nil); 
      @current_working_directory = key
      self
    end

    # Open an SSH session with +@host+. This called automatically
    # when you the first comamnd is run if it's not already connected.
    # Raises a Rye::NoHost exception if +@host+ is not specified.
    # Will attempt a password login up to 3 times if the initial 
    # authentication fails. 
    def connect
      raise Rye::NoHost unless @host
      disconnect if @ssh 
      debug "Opening connection to #{@host} as #{@opts[:user]}"
      highline = HighLine.new # Used for password prompt
      retried = 0
      
      begin
        @ssh = Net::SSH.start(@host, @opts[:user], @opts || {}) 
      rescue Net::SSH::HostKeyMismatch => ex
        STDERR.puts ex.message
        STDERR.puts "NOTE: EC2 instances generate new SSH keys on first boot."
        if highline.ask("Continue? ").match(/y|yes/i)
          @opts[:paranoid] = false
          retry
        else
          raise Net::SSH::HostKeyMismatch
        end
      rescue Net::SSH::AuthenticationFailed => ex
        retried += 1
        if STDIN.tty? && retried <= 3
          @opts[:password] = highline.ask("Password: ") { |q| q.echo = '' }
          @opts[:auth_methods] ||= []
          @opts[:auth_methods] << 'password'
          retry
        else
          raise Net::SSH::AuthenticationFailed
        end
      end
      
      # We add :auth_methods (a Net::SSH joint) to force asking for a
      # password if the initial (key-based) authentication fails. We
      # need to delete the key from @opts otherwise it lingers until
      # the next connection (if we switch_user is called for example).
      @opts.delete :auth_methods if @opts.has_key?(:auth_methods)
      
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
    
    # Reconnect as another user
    # * +newuser+ The username to reconnect as 
    #
    # NOTE: if there is an open connection, it's disconnected
    # and a new one is opened for the given user. 
    def switch_user(newuser)
      return if newuser.to_s == self.user.to_s
      @opts ||= {}
      @opts[:user] = newuser
      disconnect
      connect
    end
    
    # Open an interactive SSH session. This only works if STDIN.tty?
    # returns true. Otherwise it returns the SSH command that would 
    # have been run. This requires the SSH command-line executable (ssh).
    # * +run+ when set to false, it will return the SSH command as a String
    # and not open an SSH session.
    #
    def interactive_ssh(run=true)
      debug "interactive_ssh with keys: #{Rye.keys.inspect}"
      run = false unless STDIN.tty?      
      cmd = Rye.prepare_command("ssh", "#{@opts[:user]}@#{@host}")
      return cmd unless run
      system(cmd)
    end
    
    # Add one or more private keys to the SSH Agent. 
    # * +additional_keys+ is a list of file paths to private keys
    # Returns the instance of Box
    def add_keys(*additional_keys)
      additional_keys = [additional_keys].flatten.compact || []
      return if additional_keys.empty?
      ret = Rye.add_keys(additional_keys)
      if ret.is_a?(Rye::Rap)
        debug "ssh-add exit_code: #{ret.exit_code}" 
        debug "ssh-add stdout: #{ret.stdout}"
        debug "ssh-add stderr: #{ret.stderr}"
      end
      self #MUST RETURN itself
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
    
    def user
      (@opts || {})[:user]
    end
    
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
    
    # Returns the host SSH keys for this box
    def host_key
      raise "No host" unless @host
      Rye.remote_host_keys(@host)
    end
    
    # Copy the local public keys (as specified by Rye.keys) to 
    # this box into ~/.ssh/authorized_keys and ~/.ssh/authorized_keys2. 
    # Returns an Array of the private keys files used to generate the public keys.
    #
    # NOTE: authorize_keys disables safe-mode for this box while it runs
    # which will hit you funky style if your using a single instance
    # of Rye::Box in a multithreaded situation. 
    #
    def authorize_keys
      added_keys = []
      @safe= false
      Rye.keys.each do |key|
        path = key[2]
        debug "# Public key for #{path}"
        k = Rye::Key.from_file(path).public_key.to_ssh2
        self.mkdir(:p, :m, '700', '$HOME/.ssh') # Silently create dir if it doesn't exist
        self.echo("'#{k}' >> $HOME/.ssh/authorized_keys")
        self.echo("'#{k}' >> $HOME/.ssh/authorized_keys2")
        self.chmod('-R', '0600', '$HOME/.ssh/authorized_keys*')
        added_keys << path
      end
      @safe = true
      added_keys
    end
    
    # Authorize the current user to login to the local machine via
    # SSH without a password. This is the same functionality as
    # authorize_keys except run with local shell commands. 
    def authorize_keys_local
      added_keys = []
      Rye.keys.each do |key|
        path = key[2]
        debug "# Public key for #{path}"
        k = Rye::Key.from_file(path).public_key.to_ssh2
        Rye.shell(:mkdir, :p, :m, '700', '$HOME/.ssh') # Silently create dir if it doesn't exist
        Rye.shell(:echo, "'#{k}' >> $HOME/.ssh/authorized_keys")
        Rye.shell(:echo, "'#{k}' >> $HOME/.ssh/authorized_keys2")
        Rye.shell(:chmod, '-R', '0600', '$HOME/.ssh/authorized_keys*')
        added_keys << path
      end
      added_keys
    end
    
    # A handler for undefined commands. 
    # Raises Rye::CommandNotFound exception.
    def method_missing(meth, *args, &block)
      raise Rye::CommandNotFound, "#{meth.to_s} (args: #{args.join(' ')})"
    end
    def preview_command(*args)
      prep_args(*args).join(' ')
    end
    
  private
      
    
    def debug(msg="unknown debug msg"); @debug.puts msg if @debug; end
    def error(msg="unknown error msg"); @error.puts msg if @error; end

    
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
      debug "run_command with keys: #{Rye.keys.inspect}"
      
      cmd, args = prep_args(*args)
      
      connect if !@ssh || @ssh.closed?
      raise Rye::NotConnected, @host unless @ssh && !@ssh.closed?

      cmd_clean = Rye.escape(@safe, cmd, args)
      cmd_clean = prepend_env(cmd_clean)
      if @current_working_directory
        cwd = Rye.escape(@safe, 'cd', @current_working_directory)
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
    

    
    # Takes a list of arguments appropriate for run_command or
    # preview_command and returns: [cmd, args]
    def prep_args(*args)
      args = args.flatten.compact
      args = args.first.to_s.split(/\s+/) if args.size == 1
      cmd = args.shift
      
      # Symbols to switches. :l -> -l, :help -> --help
      args.collect! do |a|
        a = "-#{a}" if a.is_a?(Symbol) && a.to_s.size == 1
        a = "--#{a}" if a.is_a?(Symbol)
        a
      end
      [cmd, args]
    end
    
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
        # It's cool, but we'd also need to enable STDIN to interact with 
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


