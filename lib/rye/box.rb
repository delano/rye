# vim: set sw=2 ts=2 :

require 'annoy'
require 'readline'

module Rye
  DEBUG = false unless defined?(Rye::DEBUG)
  
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
  #--
  # * When anything confusing happens, enable debug in initialize
  # by passing :debug => STDERR. This will output Rye debug info
  # as well as Net::SSH info. This is VERY helpful for figuring
  # out why some command is hanging or otherwise acting weird. 
  # * If a remote command is hanging, it's probably because a
  # Net::SSH channel is waiting on_extended_data (a prompt). 
  #++
  class Box 
    include Rye::Cmd
    
    attr_accessor :rye_shell
    attr_accessor :rye_pty
    
    def host; @rye_host; end
    def opts; @rye_opts; end
    def safe; @rye_safe; end
    def user; @rye_user; end
    def root?; user.to_s == "root" end
    
    def templates; @rye_templates; end
    def templates?; !@rye_templates.nil?; end 
    
    def enable_sudo; @rye_sudo = true; end
    def disable_sudo; @rye_sudo = false; end
    def sudo?; @rye_sudo == true end
    
    # Returns the current value of the stash +@rye_stash+
    def stash; @rye_stash; end
    def quiet; @rye_quiet; end
    def via; @rye_via; end
    def nickname; @rye_nickname || host; end
    
    def host=(val); @rye_host = val; end
    def opts=(val); @rye_opts = val; end
    def via=(val); @rye_via = val; end
    
    # Store a value to the stash +@rye_stash+
    def stash=(val); @rye_stash = val; end
    def nickname=(val); @rye_nickname = val; end
    
    def enable_safe_mode;  @rye_safe = true; end
    def disable_safe_mode; @rye_safe = false; end
    def safe?; @rye_safe == true; end
    
    def enable_quiet_mode;  @rye_quiet = true; end
    def disable_quiet_mode; @rye_quiet = false; end
    
    # The most recent value from Box.cd or Box.[]
    def current_working_directory; @rye_current_working_directory; end

    # The most recent valud for umask (or 0022)
    def current_umask; @rye_current_umask; end
    
    def via?; !@rye_via.nil?; end
    def info?; !@rye_info.nil?; end
    def debug?; !@rye_debug.nil?; end
    def error?; !@rye_error.nil?; end
    
    def ostype=(val); @rye_ostype = val; end 
    def impltype=(val); @rye_impltype = val; end 
    def pre_command_hook=(val); @rye_pre_command_hook = val; end
    def stdout_hook=(val); @rye_stdout_hook = val; end
    def post_command_hook=(val); @rye_post_command_hook = val; end
    # A Hash. The keys are exception classes, the values are Procs to execute
    def exception_hook=(val); @rye_exception_hook = val; end

    # * +host+ The hostname to connect to. Default: localhost.
    # * +opts+ a hash of optional arguments.
    #
    # The +opts+ hash excepts the following keys:
    #
    # * :user => the username to connect as. Default: SSH config file or current shell user.
    # * :safe => should Rye be safe? Default: true
    # * :port => remote server ssh port. Default: SSH config file or 22
    # * :keys => one or more private key file paths (passwordless login)
    # * :via => the Rye::Hop to access this host through
    # * :info => an IO object to print Rye::Box command info to. Default: nil
    # * :debug => an IO object to print Rye::Box debugging info to. Default: nil
    # * :error => an IO object to print Rye::Box errors to. Default: STDERR
    # * :getenv => pre-fetch +host+ environment variables? (default: true)
    # * :password => the user's password (ignored if there's a valid private key)
    # * :templates => the template engine to use for uploaded files. One of: :erb (default)
    # * :sudo => Run all commands via sudo (default: false)
    # * :password_prompt => Show a password prompt on auth failure (default: true)
    #
    # NOTE: +opts+ can also contain any parameter supported by 
    # Net::SSH.start that is not already mentioned above.
    #
    def initialize(host='localhost', opts={})
      ssh_opts = ssh_config_options(host)
      @rye_exception_hook = {}
      @rye_host = host
      
      if opts[:user]
        @rye_user = opts[:user]
      else
        @rye_user = ssh_opts[:user] || Rye.sysinfo.user
      end

      # These opts are use by Rye::Box and also passed to Net::SSH
      @rye_opts = {
        :safe => true,
        :port => ssh_opts[:port],
        :keys => Rye.keys,
        :via => nil,
        :info => nil,
        :debug => nil,
        :error => STDERR,
        :getenv => true,
        :templates => :erb,
        :quiet => false,
        :password_prompt => true
      }.merge(opts)
      
      # Close the SSH session before Ruby exits. This will do nothing
      # if disconnect has already been called explicitly. 
      at_exit { self.disconnect }

      # Properly handle whether the opt :via is a +Rye::Hop+ or a +String+
      via_hop(@rye_opts.delete(:via))
      
      # @rye_opts gets sent to Net::SSH so we need to remove the keys
      # that are not meant for it. 
      @rye_safe, @rye_debug = @rye_opts.delete(:safe), @rye_opts.delete(:debug)
      @rye_info, @rye_error = @rye_opts.delete(:info), @rye_opts.delete(:error)
      @rye_getenv = {} if @rye_opts.delete(:getenv) # Enable getenv with a hash
      @rye_ostype, @rye_impltype = @rye_opts.delete(:ostype), @rye_opts.delete(:impltype)
      @rye_quiet, @rye_sudo = @rye_opts.delete(:quiet), @rye_opts.delete(:sudo)
      @rye_templates = @rye_opts.delete(:templates)
      @rye_password_prompt = @rye_opts.delete(:password_prompt)

      # Store the state of the terminal
      @rye_stty_save = `stty -g 2>/dev/null`.chomp rescue nil
      
      unless @rye_templates.nil?
        require @rye_templates.to_s   # should be :erb
      end
      
      @rye_opts[:logger] = Logger.new(@rye_debug) if @rye_debug # Enable Net::SSH debugging
      @rye_opts[:paranoid] ||= true unless @rye_safe == false # See Net::SSH.start
      @rye_opts[:keys] = [@rye_opts[:keys]].flatten.compact
      
      # Just in case someone sends a true value rather than IO object
      @rye_debug = STDERR if @rye_debug == true || DEBUG
      @rye_error = STDERR if @rye_error == true
      @rye_info = STDOUT if @rye_info == true
      
      # Add the given private keys to the keychain that will be used for @rye_host
      add_keys(@rye_opts[:keys])
      
      # We don't want Net::SSH to handle the keypairs. This may change
      # but for we're letting ssh-agent do it. 
      # TODO: Check if this should ot should not be enabled. 
      #@rye_opts.delete(:keys)
      
      # From: capistrano/lib/capistrano/cli.rb
      STDOUT.sync = true # so that Net::SSH prompts show up
      
      debug "ssh-agent info: #{Rye.sshagent_info.inspect}"
      debug @rye_opts.inspect

    end
    
    # Parse SSH config files for use with Net::SSH
    def ssh_config_options(host)
      return Net::SSH::Config.for(host)
    end
    
    # * +hops+ Rye::Hop objects will be added directly 
    # to the set. Hostnames will be used to create new instances of Rye::Hop 
    # h1 = Rye::Hop.new "host1"
    # h1.via_hop "host2", :user => "service_user"
    #
    # OR
    #
    # h1 = Rye::Hop.new "host1"
    # h2 = Rye::Hop.new "host2"
    # h1.via_hop h2
    #
    def via_hop(*args)
      args = args.flatten.compact 
      if args.first.nil?
        return @rye_via
      elsif args.first.is_a?(Rye::Hop)
        @rye_via = args.first
      elsif args.first.is_a?(String)
        hop = args.shift
        if args.first.is_a?(Hash)
          @rye_via = Rye::Hop.new(hop, args.first.merge(
                                        :debug => @rye_debug,
                                        :info => @rye_info,
                                        :error => @rye_error)
                                 )
        else
          @rye_via = Rye::Hop.new(hop)
        end
      end
      disconnect
      self
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
    def [](fpath=nil)
      if fpath.nil? || fpath.index('/') == 0
        @rye_current_working_directory = fpath
      else
        # Append to non-absolute paths
        if @rye_current_working_directory
          newpath = File.join(@rye_current_working_directory, fpath)
          @rye_current_working_directory = newpath
        else
          @rye_current_working_directory = fpath
        end
      end
      debug "CWD: #{@rye_current_working_directory}"
      self
    end
    # Like [] except it returns an empty Rye::Rap object to mimick
    # a regular command method. Call with nil key (or no arg) to 
    # reset. 
    def cd(fpath=nil)
      Rye::Rap.new(self[fpath])
    end
    
    # Change the current umask (sort of -- works the same way as cd)
    # The default umask is 0022
    def umask=(val='0022')
      @rye_current_umask = val
      self
    end
    
    
    # Reconnect as another user. This is different from su=
    # which executes subsequent commands via +su -c COMMAND USER+. 
    # * +newuser+ The username to reconnect as 
    #
    # NOTE: if there is an open connection, it's disconnected
    # but not reconnected because it's possible it wasn't 
    # connected yet in the first place (if you create the 
    # instance with default settings for example)
    def switch_user(newuser)
      return if newuser.to_s == self.user.to_s
      @rye_opts ||= {}
      @rye_user = newuser
      disconnect
    end

    
    # If STDIN.tty? is true (i.e. if we're connected to a terminal
    # with a human at the helm), this will open an SSH connection
    # via the regular SSH command (via a call to system). This 
    # requires the SSH command-line executable (ssh).
    #
    # If STDIN.tty? is false or +run+ is false, this will return 
    # the SSH command (a String) that would have been run. 
    # 
    # NOTE: As of Rye 0.9 you can run interactive sessions with
    # rye by calling any shell method without arguments. 
    #
    # e.g.
    #
    #     rbox = Rye::Box.new 'somemachine'
    #     rbox.bash
    #
    # TODO: refactor to use net_ssh_exec! in 0.9
    def interactive_ssh(run=true)
      debug "interactive_ssh with keys: #{@rye_opts[:keys].inspect}"
      run = false unless STDIN.tty?
      args = []
      @rye_opts[:keys].each { |key| args.push *[:i, key] }
      args << "#{@rye_user}@#{@rye_host}"
      cmd = Rye.prepare_command("ssh", args)
      return cmd unless run
      system(cmd)
    end
    
    # Add one or more private keys to the list of key paths.
    # * +keys+ is a list of file paths to private keys
    # Returns the instance of Box
    def add_keys(*keys)
      @rye_opts[:keys] ||= []
      @rye_opts[:keys] += keys.flatten.compact
      @rye_opts[:keys].uniq!
      self # MUST RETURN self
    end
    alias :add_key :add_keys
    
    # Remove one or more private keys fromt he list of key paths.
    # * +keys+ is a list of file paths to private keys
    # Returns the instance of Box
    def remove_keys(*keys)
      @rye_opts[:keys] ||= []
      @rye_opts[:keys] -= keys.flatten.compact
      @rye_opts[:keys].uniq!
      self # MUST RETURN self
    end
    alias :remove_key :remove_keys
    
    # Return the value of uname in lowercase
    # This is a temporary fix. We can use SysInfo for this, upload
    # it, execute it directly, parse the output.
    def ostype
      return @rye_ostype if @rye_ostype # simple cache
      os = self.quietly { uname.first } rescue nil
      os ||= 'unknown'
      os &&= os.downcase
      @rye_ostype = os
    end
    
    def impltype
      @rye_impltype
    end
    
    # Returns the hash containing the parsed output of "env" on the 
    # remote machine. If the initialize option +:getenv+ was set to 
    # false, this will return an empty hash. 
    # This is a lazy loaded method so it fetches the remote envvars
    # the first time this method is called. 
    #
    #      puts rbox.getenv['HOME']    # => "/home/gloria" (remote)
    #
    # NOTE: This method should not raise an exception under normal
    # circumstances. 
    #
    def getenv(key=nil)
      if @rye_getenv && @rye_getenv.empty? && self.can?(:env)
        vars = self.quietly { env } rescue []
        vars.each do |nvpair| 
          # Parse "GLORIA_HOME=/gloria/lives/here" into a name/value
          # pair. The regexp ensures we split only at the 1st = sign
          n, v = nvpair.scan(/\A([\w_-]+?)=(.+)\z/).flatten
          @rye_getenv[n] = v
        end
      end
      key.nil? ? @rye_getenv : @rye_getenv[key.to_s]
    end
    
    # Add an environment variable. +n+ and +v+ are the name and value.
    # Returns the instance of Rye::Box
    def setenv(n, v)
      debug "Adding env: #{n}=#{v}"
      debug "prev value: #{@rye_getenv[n]}"
      @rye_getenv[n] = v
      (@rye_current_environment_variables ||= {})[n] = v
      self
    end
    alias :add_env :setenv  # deprecated?
    
    # See Rye.keys
    def keys; Rye.keys; end
    
    # Returns +user@rye_host+
    def to_s; '%s@rye_%s' % [user, @rye_host]; end
    
    def inspect
      %q{#<%s:%s name=%s cwd=%s umask=%s env=%s safe=%s opts=%s keys=%s>} % 
      [self.class.to_s, self.host, self.nickname,
       @rye_current_working_directory, @rye_current_umask,
       (@rye_current_environment_variables || '').inspect,
       self.safe, self.opts.inspect, self.keys.inspect]
    end
    
    # Compares itself with the +other+ box. If the hostnames
    # are the same, this will return true. Otherwise false. 
    def ==(other)
      @rye_host == other.host
    end
    
    # Returns the host SSH keys for this box
    def host_key
      raise "No host" unless @rye_host
      Rye.remote_host_keys(@rye_host)
    end
    
    # Uses the output of "useradd -D" to determine the default home
    # directory. This returns a GUESS rather than the a user's real
    # home directory. Currently used only by authorize_keys_remote.
    # Only useful before you've logged in. Otherwise check $HOME
    def guess_user_home(other_user=nil)
      this_user = other_user || opts[:user]
      @rye_guessed_homes ||= {}
      
      # A simple cache. 
      return @rye_guessed_homes[this_user] if @rye_guessed_homes.has_key?(this_user)
      
      # Some junk to determine where user home directories are by default.
      # We're relying on the command "useradd -D" so this may not work on
      # different Linuxen and definitely won't work on Windows.
      # This code will be abstracted out once I find a decent home for it.
      # /etc/default/useradd, HOME=/home OR useradd -D
      # /etc/adduser.config, DHOME=/home OR ??
      user_defaults = {}
      ostmp = self.ostype
      ostmp &&= ostype.to_s
      
      if ostmp == "sunos"
        #nv.scan(/([\w_-]+?)=(.+?)\s/).each do |n, v|
        #  n = 'HOME' if n == 'basedir'
        #  user_defaults[n.upcase] = v.strip
        #end
        # In Solaris, useradd -D says the default home path is /home
        # but that directory is not writable. See: http://bit.ly/IJDD0
        user_defaults['HOME'] = '/export/home'
      elsif ostmp == "darwin"
        user_defaults['HOME'] = '/Users'
      elsif ostmp == "windows"
        user_defaults['HOME'] = 'C:/Documents and Settings'
      else
        raw = self.quietly { useradd(:D) } rescue []
        raw = ["HOME=/home"] if raw.nil? || raw.empty?
        raw.each do |nv|
          n, v = nv.scan(/\A([\w_-]+?)=(.+)\z/).flatten
          user_defaults[n] = v
        end
      end
      
      @rye_guessed_homes[this_user] = "#{user_defaults['HOME']}/#{this_user}"
    end
    
    # A handler for undefined commands. 
    # Raises Rye::CommandNotFound exception.
    def method_missing(cmd, *args, &block)
      if cmd == :to_ary
        super
      elsif @rye_safe
        ex = Rye::CommandNotFound.new(cmd.to_s)
        raise ex unless @rye_exception_hook.has_key? ex.class
        @rye_exception_hook[Rye::CommandNotFound].call ex
      else
        if block.nil?
          run_command cmd, *args
        else
          ex = Rye::CommandNotFound.new(cmd.to_s)
          raise ex unless @rye_exception_hook.has_key? ex.class
        end
      end
    end
    alias :execute :method_missing

    # Returns the command an arguments as a String. 
    def preview_command(*args)
      prep_args(*args).join(' ')
    end
    
    
    # Supply a block to be called before every command. It's called
    # with three arguments: command name, an Array of arguments, user name, hostname
    # e.g.
    #     rbox.pre_command_hook do |cmd,args,user,host|
    #       ...
    #     end
    def pre_command_hook(&block)
      @rye_pre_command_hook = block if block
      @rye_pre_command_hook
    end
    
    # Supply a block to be called every time a command receives STDOUT data.
    # 
    # e.g.
    #     rbox.stdout_hook do |content|
    #       ...
    #     end
    def stdout_hook(&block)
      @rye_stdout_hook = block if block
      @rye_stdout_hook
    end
    
    # Supply a block to be called whenever there's an Exception. It's called
    # with 1 argument: the exception class. If the exception block returns 
    # :retry, the command will be executed again. 
    #
    # e.g.
    #     rbox.exception_hook(CommandNotFound) do |ex|
    #       STDERR.puts "An error occurred: #{ex.class}"
    #       choice = Annoy.get_user_input('(S)kip  (R)etry  (A)bort: ')
    #       if choice == 'R'
    #         :retry 
    #       elsif choice == 'S'
    #         # do nothing
    #       else
    #         exit  # !
    #       end
    #     end
    def exception_hook(klass, &block)
      @rye_exception_hook[klass] = block if block
      @rye_exception_hook[klass]
    end
    
    # Execute a block in the context of an instance of Rye::Box. 
    #
    #     rbox = Rye::Box.new
    #
    #     rbox.batch do
    #       ls :l
    #       uname :a
    #     end
    # OR
    #     rbox.batch(&block)
    #
    # The batch can also accept arguments.
    #
    #     rbox.batch('path/2/file') do |file|
    #       ls :l file
    #     end
    #
    # Returns the return value of the block. 
    #
    def batch(*args, &block)
      self.instance_exec(*args, &block)
    end
    
    # Like batch, except it disables safe mode before executing the block. 
    # After executing the block, safe mode is returned back to whichever
    # state it was previously in. In other words, this method won't enable
    # safe mode if it was already disabled.
    def unsafely(*args, &block)
      previous_state = @rye_safe
      disable_safe_mode
      ret = self.instance_exec *args, &block
      @rye_safe = previous_state
      ret
    end
    alias_method :wildly, :unsafely
    
    # See unsafely (except in reverse)
    def safely(*args, &block)
      previous_state = @rye_safe
      enable_safe_mode
      ret = self.instance_exec *args, &block
      @rye_safe = previous_state
      ret
    end
    
    # Like batch, except it enables quiet mode before executing the block. 
    # After executing the block, quiet mode is returned back to whichever
    # state it was previously in. In other words, this method won't enable
    # quiet mode if it was already disabled.
    #
    # In quiet mode, the pre and post command hooks are not called. This 
    # is used internally when calling commands like +ls+ to check whether
    # a file path exists (to prevent polluting the logs).
    def quietly(*args, &block)
      previous_state = @rye_quiet
      enable_quiet_mode
      ret = self.instance_exec *args, &block
      @rye_quiet = previous_state
      ret
    end
    
    # Like batch, except it enables sudo mode before executing the block.
    # If the user is already root, this has no effect. Otherwise all 
    # commands executed in the block will run via sudo. 
    #
    # If no block is specified then sudo is called just like a regular
    # command.
    def sudo(*args, &block)
      if block.nil?
        run_command('sudo', args);
      else
        previous_state = @rye_sudo
        enable_sudo
        ret = self.instance_exec *args, &block
        @rye_sudo = previous_state
        ret  
      end
    end
    
    # instance_exec for Ruby 1.8 written by Mauricio Fernandez
    # http://eigenclass.org/hiki/instance_exec
    if RUBY_VERSION =~ /1.8/
      module InstanceExecHelper; end
      include InstanceExecHelper
      def instance_exec(*args, &block) # !> method redefined; discarding old instance_exec
        mname = "__instance_exec_#{Thread.current.object_id.abs}_#{object_id.abs}"
        InstanceExecHelper.module_eval{ define_method(mname, &block) }
        begin
          ret = send(mname, *args)
        ensure
          InstanceExecHelper.module_eval{ undef_method(mname) } rescue nil
        end
        ret
      end
    end
    
    # Supply a block to be called after every command. It's called
    # with one argument: an instance of Rye::Rap.
    #
    # When this block is supplied, the command does not raise an 
    # exception when the exit code is greater than 0 (the typical
    # behavior) so the block needs to check the Rye::Rap object to
    # determine whether an exception should be raised. 
    def post_command_hook(&block)
      @rye_post_command_hook = block if block
      @rye_post_command_hook
    end

    
    
    # Open an SSH session with +@rye_host+. This called automatically
    # when you the first comamnd is run if it's not already connected.
    # Raises a Rye::NoHost exception if +@rye_host+ is not specified.
    # Will attempt a password login up to 3 times if the initial 
    # authentication fails. 
    # * +reconnect+ Disconnect first if already connected. The default
    # is true. When set to false, connect will do nothing if already 
    # connected. 
    def connect(reconnect=true)
      raise Rye::NoHost unless @rye_host
      return if @rye_ssh && !reconnect
      disconnect if @rye_ssh 
      if @rye_via
        debug "Opening connection to #{@rye_host} as #{@rye_user}, via #{@rye_via.host}"
      else
        debug "Opening connection to #{@rye_host} as #{@rye_user}"
      end
      highline = HighLine.new # Used for password prompt
      retried = 0
      @rye_opts[:keys].compact!  # A quick fix in Windows. TODO: Why is there a nil?
      begin
        if @rye_via
          # tell the +Rye::Hop+ what and where to setup,
          # it returns the local port used
          @rye_localport = @rye_via.fetch_port(@rye_host, @rye_opts[:port].nil? ? 22 : @rye_opts[:port] )
          debug "fetched localport #{@rye_localport}"
          @rye_ssh = Net::SSH.start("localhost", @rye_user, @rye_opts.merge(:port => @rye_localport) || {}) 
        else
          @rye_ssh = Net::SSH.start(@rye_host, @rye_user, @rye_opts || {}) 
        end
      rescue Net::SSH::HostKeyMismatch => ex
        STDERR.puts ex.message
        print "\a" if @rye_info # Ring the bell
        raise ex
      rescue Net::SSH::AuthenticationFailed => ex
        print "\a" if retried == 0 && @rye_info # Ring the bell once
        retried += 1

        @rye_opts[:auth_methods] ||= []

        # Raise Net::SSH::AuthenticationFailed if publickey is the 
        # only auth method
        if @rye_opts[:auth_methods] == ["publickey"]
          raise ex
        elsif @rye_password_prompt && (STDIN.tty? && retried <= 3)
          STDERR.puts "Passwordless login failed for #{@rye_user}"
          @rye_opts[:password] = highline.ask("Password: ") { |q| q.echo = '' }.strip
          @rye_opts[:auth_methods].push *['keyboard-interactive', 'password']
          retry
        else
          raise ex
        end
      end
      
      # We add :auth_methods (a Net::SSH joint) to force asking for a
      # password if the initial (key-based) authentication fails. We
      # need to delete the key from @rye_opts otherwise it lingers until
      # the next connection (if we switch_user is called for example).
      @rye_opts.delete :auth_methods if @rye_opts.has_key?(:auth_methods)
      
      self
    end
    
    # Close the SSH session  with +@rye_host+. This is called 
    # automatically at exit if the connection is open. 
    def disconnect
      return unless @rye_ssh && !@rye_ssh.closed?
      begin
        if @rye_ssh.busy?;
          info "Is something still running? (ctrl-C to exit)"
          Timeout::timeout(10) do
            @rye_ssh.loop(0.3) { @rye_ssh.busy?; }
          end
        end
        debug "Closing connection to #{@rye_ssh.host}"
        @rye_ssh.close
        if @rye_via
          debug "disconnecting Hop #{@rye_via.host}"
          @rye_via.disconnect
        end
      rescue SystemCallError, Timeout::Error => ex
        error "Rye::Box: Disconnect timeout (#{ex.message})"
        debug ex.backtrace
      rescue Interrupt
        debug "Exiting..."
      end
    end
    
    
  private
      
    def debug(msg="unknown debug msg"); @rye_debug.puts msg if @rye_debug; end
    def error(msg="unknown error msg"); @rye_error.puts msg if @rye_error; end
    def pinfo(msg="unknown info msg"); @rye_info.print msg if @rye_info; end
    def info(msg="unknown info msg"); @rye_info.puts msg if @rye_info; end
    
    # Add the current environment variables to the beginning of +cmd+
    def prepend_env(cmd)
      return cmd unless @rye_current_environment_variables.is_a?(Hash)
      env = ''
      @rye_current_environment_variables.each_pair do |n,v|
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
    #     rbox.ls :l, 'arg1', 'arg2'
    #
    # is equivalent to
    #
    #     $ ls -l 'arg1' 'arg2'
    #
    # This method will try to connect to the host automatically
    # but if it fails it will raise a Rye::NotConnected exception. 
    # 
    def run_command(*args, &blk)
      debug "run_command"
      
      cmd, args = prep_args(*args)
      
      #p [:run_command, cmd, blk.nil?]
      
      connect if !@rye_ssh || @rye_ssh.closed?
      raise Rye::NotConnected, @rye_host unless @rye_ssh && !@rye_ssh.closed?
      
      cmd_clean = Rye.escape(@rye_safe, cmd, args)
      
      # This following is the command we'll actually execute. cmd_clean
      # can be used for logging, otherwise the output is confusing.
      cmd_internal = prepend_env(cmd_clean)
      
      # Add the current working directory before the command if supplied. 
      # The command will otherwise run in the user's home directory.
      if @rye_current_working_directory
        cwd = Rye.escape(@rye_safe, 'cd', @rye_current_working_directory)
        cmd_internal = '(%s; %s)' % [cwd, cmd_internal]
      end
      
      # ditto (same explanation as cwd)
      if @rye_current_umask
        cwd = Rye.escape(@rye_safe, 'umask', @rye_current_umask)
        cmd_internal = [cwd, cmd_internal].join(' && ')
      end
      
      ## NOTE: Do not raise a CommandNotFound exception in this method.
      # We want it to be possible to define methods to a single instance
      # of Rye::Box. i.e. def rbox.rm()...
      # can? returns the methods in Rye::Cmd so it would incorrectly
      # return false. We could use self.respond_to? but it's possible
      # to get a name collision. I could write a work around but I think
      # this is good enough for now. 
      ## raise Rye::CommandNotFound unless self.can?(cmd)
      
      begin
        debug "COMMAND: #{cmd_internal}"

        if !@rye_quiet && @rye_pre_command_hook.is_a?(Proc)
          @rye_pre_command_hook.call(cmd_clean, user, host, nickname) 
        end
        
        rap = Rye::Rap.new(self)
        rap.cmd = cmd_clean
        
        channel = net_ssh_exec!(cmd_internal, &blk)
        channel[:stderr].position = 0
        channel[:stdout].position = 0
        
        if channel[:exception]
          rap = channel[:exception].rap
        else
          rap.add_stdout(channel[:stdout].read || '')
          rap.add_stderr(channel[:stderr].read || '')
          rap.add_exit_status(channel[:exit_status])
          rap.exit_signal = channel[:exit_signal]
        end
        
        debug "RESULT: %s " % [rap.inspect]
        
        # It seems a convention for various commands to return -1
        # when something only mildly concerning happens. (ls even 
        # returns -1 for apparently no reason sometimes). Anyway,
        # the real errors are the ones that are greater than zero.
        raise Rye::Err.new(rap) if rap.exit_status != 0
        
      rescue Exception => ex
        return rap if @rye_quiet
        choice = nil
        @rye_exception_hook.each_pair do |klass,act|
          next unless ex.kind_of? klass
          choice = act.call(ex, cmd_clean, user, host, nickname)
          break
        end
        if choice == :retry
          retry
        elsif choice == :skip
          # do nothing
        elsif choice == :interactive && !@rye_shell
          @rye_shell = true
          previous_state = @rye_sudo
          disable_sudo
          bash
          @rye_sudo = previous_state
          @rye_shell = false
        elsif !ex.is_a?(Interrupt)
          raise ex, ex.message
        end
      end
      
      if !@rye_quiet && @rye_post_command_hook.is_a?(Proc)
        @rye_post_command_hook.call(rap)
      end
      
      rap
    end
    alias :__allow :run_command
    
    # Takes a list of arguments appropriate for run_command or
    # preview_command and returns: [cmd, args]. 
    # Single character symbols with be converted to command line
    # switches. Example:   +:l+ becomes +-l+
    def prep_args(*args)
      args = args.flatten.compact
      args = args.first.to_s.split(/\s+/) if args.size == 1
      cmd = sudo? ? :sudo : args.shift
      
      # Symbols to switches. :l -> -l, :help -> --help
      args.collect! do |a|
        if a.is_a?(Symbol)
          a = (a.to_s.size == 1) ? "-#{a}" : a.to_s
        end
        a
      end
      [cmd, args]
    end
    
    def net_ssh_exec!(cmd, &blk)
      debug ":net_ssh_exec #{cmd} (has blk: #{!blk.nil?}; pty: #{@rye_pty}; shell: #{@rye_shell})"
      
      pty_opts =   { :term => "xterm",
                              :chars_wide  => 80,
                              :chars_high  => 24,
                              :pixels_wide => 640,
                              :pixels_high => 480,
                              :modes       => {} }
      
      channel = @rye_ssh.open_channel do |channel|
        if self.rye_shell && blk.nil?
          channel.request_pty(pty_opts) do |ch,success|
            self.rye_pty = success
            raise Rye::NoPty if !success
          end
        end
        channel.exec(cmd, &create_channel)
        channel[:state] = :start_session
        channel[:block] = blk
      end
      
      @rye_channels ||= []
      @rye_channels << channel
      
      @rye_ssh.loop(0.1) do
        break if channel.nil? || !channel.active?
        !channel.eof?   # otherwise keep returning true
      end
      
      channel
    end
    
    
    def state_wait_for_command(channel)
      debug :wait_for_command
    end

    def state_start_session(channel)
      debug "#{:start_session} [blk: #{!channel[:block].nil?}] [pty: #{@rye_pty}] [shell: #{@rye_shell}]"
      channel[:state] = nil
      channel[:state] = :run_block if channel[:block] 
      channel[:state] = :await_response if @rye_pty
    end
    
    def state_await_response(channel)
      debug :await_response
      @await_response_counter ||= 0
      if channel[:stdout].available > 0 || channel[:stderr].available > 0
        channel[:state] = :read_response
      elsif @await_response_counter > 50
        @await_response_counter = 0
        channel[:state] = :await_input
      end
      @await_response_counter += 1
    end
    
    def state_read_response(channel)
      debug :read_response
      if channel[:stdout].available > 0 || channel[:stderr].available > 0
        
        stdout = channel[:stdout].read if channel[:stdout].available > 0
        stderr = channel[:stderr].read if channel[:stderr].available > 0
        
        print stdout if stdout
        print stderr if stderr
        
        if channel[:stack].empty?
          channel[:state] = :await_input
        elsif channel[:stdout].available > 0 || channel[:stderr].available > 0
          channel[:state] = :read_response
        else
          channel[:state] = :send_data
        end
      else
        channel[:state] = :await_response
      end
      
    end

    def state_send_data(channel)
      debug :send_data
      cmd = channel[:stack].shift
      debug "sending #{cmd.inspect}"
      channel[:state] = :await_response
      channel.send_data("#{cmd}\n") unless channel.eof?
    end
    
    def state_await_input(channel)
      debug :await_input
        if channel[:stdout].available > 0
          channel[:state] = :read_response
        else
          ret = nil
          if channel[:prompt] && (channel[:prompt] =~ /pass/i)
            ret = Annoy.get_user_input("#{channel[:prompt]} ", echo='*', period=30)
            channel[:prompt] = nil
          end
          begin
            list = self.commands.sort

            comp = proc { |s| 
              # TODO: Something here for files
              list.grep( /^#{Regexp.escape(s)}/ ) 
            }

            Readline.completion_append_character = " "
            Readline.completion_proc = comp
            
            ret = Readline.readline(channel[:prompt] || '', true)
            #ret = STDIN.gets
            
            if ret.nil?
              channel[:state] = :exit
            else
              channel[:stack] << ret.chomp
              channel[:state] = :send_data
            end
          rescue Interrupt => e
            channel[:state] = :exit
          end
          channel[:prompt] = nil
        end
    end
    
    def state_ignore_response(channel)
      debug :ignore_response
      @ignore_response_counter ||= 0
      if channel[:stdout].available > 0
        @await_response_counter = 0
        channel[:stdout].read
        channel[:state] = :process
      elsif @ignore_response_counter > 2
        @await_response_counter = 0
        channel[:state] = :process
      end
      @ignore_response_counter += 1
    end
    
    def state_exit(channel)
      debug :exit_state
      channel[:state] = nil
      if rye_shell && (!channel.eof? || !channel.closing?)
        puts
        channel.send_data("exit\n")
      else
        channel.eof!
      end
    end
    
    # TODO: implement callback in create_channel Proc
    ##def state_handle_error(channel)
    ##  debug :handle_error
    ##  channel[:state] = nil
    ##  if rye_shell && (!channel.eof? || !channel.closing?)
    ##    puts
    ##    channel.send_data("exit\n")
    ##  else
    ##    channel.eof!
    ##  end
    ##end
    

    def state_run_block(channel)
      debug :run_block
      channel[:state] = nil
      blk = channel[:block]
      channel[:block] = nil
      begin
        instance_eval &blk
      rescue => ex
        channel[:exception] = ex
      end
      channel[:state] = :exit
    end
    
    def create_channel()
      Proc.new do |channel,success|
        channel[:stdout  ] = Net::SSH::Buffer.new
        channel[:stderr  ] = Net::SSH::Buffer.new
        channel[:stack] ||= []
        channel.on_close                  { |ch|  
          channel[:handler] = ":on_close"
        }
        channel.on_data                   { |ch, data| 
          channel[:handler] = ":on_data"
          @rye_stdout_hook.call(data, user, host, nickname) if !@rye_pty && !@rye_quiet && @rye_stdout_hook.kind_of?(Proc)
          if rye_pty && data =~ /password/i
            channel[:prompt] = data
            channel[:state] = :await_input
          else
            channel[:stdout].append(data) 
          end
        }
        channel.on_extended_data          { |ch, type, data| 
          channel[:handler] = ":on_extended_data"
          if rye_pty && data =~ /\Apassword/i
            channel[:prompt] = data
            channel[:state] = :await_input
          else
            channel[:stderr].append(data)
          end
        }
        channel.on_request("exit-status") { |ch, data| 
          channel[:handler] = ":on_request (exit-status)"
          channel[:exit_status] = data.read_long 
        }
        channel.on_request("exit-signal") do |ch, data|
          channel[:handler] = ":on_request (exit-signal)"
          # This should be the POSIX SIGNAL that ended the process
          channel[:exit_signal] = data.read_long
        end
        channel.on_process                { 
          channel[:handler] = :on_process
          STDERR.print channel[:stderr].read if channel[:stderr].available > 0
          begin
            send("state_#{channel[:state]}", channel) unless channel[:state].nil?
          rescue Interrupt
            debug :on_process_interrupt
            channel[:state] = :exit
          end
        }
      end
    end
    
    
    
    # * +direction+ is one of :upload, :download
    # * +recursive+ should be true for directories and false for files. 
    # * +files+ is an Array of file paths, the content is direction specific.
    # For downloads, +files+ is a list of files to download. The last element
    # must be the local directory to download to. If downloading a single file
    # the last element can be a file path. The target can also be a StringIO.
    # For uploads, +files+ is a list of files to upload. The last element is
    # the directory to upload to. If uploading a single file, the last element
    # can be a file path. The list of files can also include StringIO objects.
    # For both uploads and downloads, the target directory will be created if
    # it does not exist, but only when multiple files are being transferred. 
    # This method will fail early if there are obvious problems with the input
    # parameters. An exception is raised and no files are transferred. 
    # Uploads always return nil. Downloads return nil or a StringIO object if
    # one is specified for the target. 
    def net_scp_transfer!(direction, recursive, *files)
      
      unless [:upload, :download].member?(direction.to_sym)
        raise "Must be one of: upload, download" 
      end
      
      if @rye_current_working_directory
        debug "CWD (#{@rye_current_working_directory})"
      end
      
      files = [files].flatten.compact || []

      # We allow a single file to be downloaded into a StringIO object
      # but only when no target has been specified. 
      if direction == :download 
        if files.size == 1
          debug "Created StringIO for download"
          target = StringIO.new
        else
          target = files.pop   # The last path is the download target.
        end
        
      elsif direction == :upload
#        p :UPLOAD, @rye_templates
        raise "Cannot upload to a StringIO object" if target.is_a?(StringIO)
        if files.size == 1
          target = self.getenv['HOME'] || guess_user_home
          debug "Assuming upload to #{target}"
        else
          target = files.pop
        end
        
        # Expand fileglobs (e.g. path/*.rb becomes [path/1.rb, path/2.rb]).
        # This should happen after checking files.size to determine the target
        unless @rye_safe
          files.collect! { |file| 
            file.is_a?(StringIO) ? file : Dir.glob(File.expand_path(file)) 
          }
          files.flatten! 
        end
      end
              
      # Fail early. We check whether the StringIO object is available to read
      files.each do |file|
        if file.is_a?(StringIO)
          raise "Cannot download a StringIO object" if direction == :download
          raise "StringIO object not opened for reading" if file.closed_read?
          # If a StringIO object is at end of file, SCP will hang. (TODO: SCP)
          file.rewind if file.eof?
        end
      end
      
      debug "FILES: " << files.join(', ')
      
      # Make sure the target directory exists. We can do this only when
      # there's more than one file because "target" could be a file name
      if files.size > 1 && !target.is_a?(StringIO)
        debug "CREATING TARGET DIRECTORY: #{target}"
        self.mkdir(:p, target) unless self.file_exists?(target)
      end
      
      Net::SCP.start(@rye_host, @rye_user, @rye_opts || {}) do |scp|
        transfers = []
        prev = ""
        files.each do |file|
          debug file.to_s
          prev = ""
          line = nil
          transfers << scp.send(direction, file, target, :recursive => recursive)  do |ch, n, s, t|
            line = "%-50s %6d/%-6d bytes" % [n, s, t]
            spaces = (prev.size > line.size) ? ' '*(prev.size - line.size) : ''
            pinfo "[%s] %s %s %s" % [direction, line, spaces, s == t ? "\n" : "\r"]   # update line: "file: sent/total"
            @rye_info.flush if @rye_info        # make sure every line is printed
            prev = line
          end
        end
        transfers.each { |t| t.wait }   # Run file transfers in parallel
      end
      
      target.is_a?(StringIO) ? target : nil
    end
    

  end
end


