

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
    
    def host; @rye_host; end
    def opts; @rye_opts; end
    def safe; @rye_safe; end
    def user; (@rye_opts || {})[:user]; end
    
    # Returns the current value of the stash +@rye_stash+
    def stash; @rye_stash; end
    def quiet; @rye_quiet; end
    def nickname; @rye_nickname || host; end
    
    def host=(val); @rye_host = val; end
    def opts=(val); @rye_opts = val; end
    
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
    
    def info; @rye_info; end
    def debug; @rye_debug; end
    def error; @rye_error; end
    
    def ostype=(val); @rye_ostype = val; end 
    def impltype=(val); @rye_impltype = val; end 
    def pre_command_hook=(val); @rye_pre_command_hook = val; end
    def post_command_hook=(val); @rye_post_command_hook = val; end
    # A Hash. The keys are exception classes, the values are Procs to execute
    def exception_hook=(val); @rye_exception_hook = val; end

    # * +host+ The hostname to connect to. The default is localhost.
    # * +opts+ a hash of optional arguments.
    #
    # The +opts+ hash excepts the following keys:
    #
    # * :user => the username to connect as. Default: the current user. 
    # * :safe => should Rye be safe? Default: true
    # * :keys => one or more private key file paths (passwordless login)
    # * :info => an IO object to print Rye::Box command info to. Default: nil
    # * :debug => an IO object to print Rye::Box debugging info to. Default: nil
    # * :error => an IO object to print Rye::Box errors to. Default: STDERR
    # * :getenv => pre-fetch +host+ environment variables? (default: true)
    # * :password => the user's password (ignored if there's a valid private key)
    #
    # NOTE: +opts+ can also contain any parameter supported by 
    # Net::SSH.start that is not already mentioned above.
    #
    def initialize(host='localhost', opts={})
      @rye_exception_hook = {}
      @rye_host = host
      
      # These opts are use by Rye::Box and also passed to Net::SSH
      @rye_opts = {
        :user => Rye.sysinfo.user, 
        :safe => true,
        :port => 22,
        :keys => [],
        :info => nil,
        :debug => nil,
        :error => STDERR,
        :getenv => true,
        :quiet => false
      }.merge(opts)
      
      # Close the SSH session before Ruby exits. This will do nothing
      # if disconnect has already been called explicitly. 
      at_exit { self.disconnect }
      
      # @rye_opts gets sent to Net::SSH so we need to remove the keys
      # that are not meant for it. 
      @rye_safe, @rye_debug = @rye_opts.delete(:safe), @rye_opts.delete(:debug)
      @rye_info, @rye_error = @rye_opts.delete(:info), @rye_opts.delete(:error)
      @rye_getenv = {} if @rye_opts.delete(:getenv) # Enable getenv with a hash
      @rye_ostype, @rye_impltype = @rye_opts.delete(:ostype), @rye_opts.delete(:impltype)
      @rye_quiet = @rye_opts.delete(:quiet)
      
      # Just in case someone sends a true value rather than IO object
      @rye_debug = STDERR if @rye_debug == true
      @rye_error = STDERR if @rye_error == true
      @rye_info = STDOUT if @rye_info == true
      
      @rye_opts[:logger] = Logger.new(@rye_debug) if @rye_debug # Enable Net::SSH debugging
      @rye_opts[:paranoid] = true unless @rye_safe == false # See Net::SSH.start
      @rye_opts[:keys] = [@rye_opts[:keys]].flatten.compact
      
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
      @rye_opts[:user] = newuser
      disconnect
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
      cmd = Rye.prepare_command("ssh", "#{@rye_opts[:user]}@#{@rye_host}")
      return cmd unless run
      system(cmd)
    end
    
    # Add one or more private keys to the SSH Agent. 
    # * +additional_keys+ is a list of file paths to private keys
    # Returns the instance of Box
    def add_keys(*additional_keys)
      if Rye.sysinfo.os == :windows
        @rye_opts[:keys] ||= []
        @rye_opts[:keys] += additional_keys.flatten
        return @rye_opts[:keys]
      end
      additional_keys = [additional_keys].flatten.compact || []
      return if additional_keys.empty?
      ret = Rye.add_keys(additional_keys) 
      if ret.is_a?(Rye::Rap)
        debug "ssh-add exit_code: #{ret.exit_code}" 
        debug "ssh-add stdout: #{ret.stdout}"
        debug "ssh-add stderr: #{ret.stderr}"
      end
      self # MUST RETURN self
    end
    alias :add_key :add_keys
    
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
        raw = self.quietly { useradd(:D) } rescue ["HOME=/home"]
        raw.each do |nv|
          n, v = nv.scan(/\A([\w_-]+?)=(.+)\z/).flatten
          user_defaults[n] = v
        end
      end
      
      @rye_guessed_homes[this_user] = "#{user_defaults['HOME']}/#{this_user}"
    end
    
    # Copy the local public keys (as specified by Rye.keys) to 
    # this box into ~/.ssh/authorized_keys and ~/.ssh/authorized_keys2. 
    # Returns a Rye::Rap object. The private keys files used to generate 
    # the public keys are contained in stdout.
    # Raises a Rye::ComandError if the home directory doesn't exit. 
    # NOTE: authorize_keys_remote disables safe-mode for this box while it runs
    # which will hit you funky style if your using a single instance
    # of Rye::Box in a multithreaded situation. 
    #
    def authorize_keys_remote(other_user=nil)
      this_user = other_user || opts[:user]
      added_keys = []
      rap = Rye::Rap.new(self)
      
      prevdir = self.current_working_directory
      
      # The homedir path is important b/c this is where we're going to 
      # look for the .ssh directory. That's where auth love is stored.
      homedir = self.guess_user_home(this_user)
      
      unless self.file_exists?(homedir)
        rap.add_exit_code(1)
        rap.add_stderr("Path does not exist: #{homedir}")
        raise Rye::CommandError.new(rap)
      end
      
      # Let's go into the user's home directory that we now know exists.
      self.cd homedir
      
      files = ['.ssh/authorized_keys', '.ssh/authorized_keys2']
      files.each do |akey_path|
        if self.file_exists?(akey_path)
          # TODO: Make Rye::Cmd.incremental_backup
          self.cp(akey_path, "#{akey_path}-previous")
          authorized_keys = self.file_download("#{homedir}/#{akey_path}")
        end
        authorized_keys ||= StringIO.new
        
        Rye.keys.each do |path|
          
          info "# Adding public key for #{path}"
          k = Rye::Key.from_file(path).public_key.to_ssh2
          authorized_keys.puts k
        end
        
        # Remove duplicate authorized keys
        authorized_keys.rewind
        uniqlines = authorized_keys.readlines.uniq.join
        authorized_keys = StringIO.new(uniqlines)
        # We need to rewind so that all of the StringIO object is uploaded
        authorized_keys.rewind
        
        self.mkdir(:p, :m, '700', File.dirname(akey_path))
        self.file_upload(authorized_keys, "#{homedir}/#{akey_path}")
        self.chmod('0600', akey_path)
        self.chown(:R, this_user.to_s, File.dirname(akey_path))
      end
      
      # And let's return to the directory we came from.
      self.cd prevdir
      
      rap.add_exit_code(0)
      rap
    end
    require 'fileutils'
    # Authorize the current user to login to the local machine via
    # SSH without a password. This is the same functionality as
    # authorize_keys_remote except run with local shell commands. 
    def authorize_keys_local
      added_keys = []
      ssh_dir = File.join(Rye.sysinfo.home, '.ssh')
      Rye.keys.each do |path|
        debug "# Public key for #{path}"
        k = Rye::Key.from_file(path).public_key.to_ssh2
        FileUtils.mkdir ssh_dir unless File.exists? ssh_dir
        
        authkeys_file = File.join(ssh_dir, 'authorized_keys')
        
        debug "Writing to #{authkeys_file}"
        File.open(authkeys_file, 'a')       {|f| f.write("#{$/}#{k}") }
        File.open("#{authkeys_file}2", 'a') {|f| f.write("#{$/}#{k}") }
        
        unless Rye.sysinfo.os == :windows
          Rye.shell(:chmod, '700', ssh_dir)
          Rye.shell(:chmod, '0600', authkeys_file)
          Rye.shell(:chmod, '0600', "#{authkeys_file}2")
        end
        
        added_keys << path
      end
      added_keys
    end
    
    # A handler for undefined commands. 
    # Raises Rye::CommandNotFound exception.
    def method_missing(cmd, *args, &block)
      if @rye_safe
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
      self.instance_exec *args, &block
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
      debug "Opening connection to #{@rye_host} as #{@rye_opts[:user]}"
      highline = HighLine.new # Used for password prompt
      retried = 0
      @rye_opts[:keys].compact!  # A quick fix in Windows. TODO: Why is there a nil?
      begin
        @rye_ssh = Net::SSH.start(@rye_host, @rye_opts[:user], @rye_opts || {}) 
      rescue Net::SSH::HostKeyMismatch => ex
        STDERR.puts ex.message
        print "\a" if @rye_info # Ring the bell
        if highline.ask("Continue? ").strip.match(/\Ay|yes|sure|ya\z/i)
          @rye_opts[:paranoid] = false
          retry
        else
          raise Net::SSH::HostKeyMismatch
        end
      rescue Net::SSH::AuthenticationFailed => ex
        print "\a" if retried == 0 && @rye_info # Ring the bell once
        retried += 1
        if STDIN.tty? && retried <= 3
          STDERR.puts "Passwordless login failed for #{@rye_opts[:user]}"
          @rye_opts[:password] = highline.ask("Password: ") { |q| q.echo = '' }
          @rye_opts[:auth_methods] ||= []
          @rye_opts[:auth_methods] << 'password'
          retry
        else
          raise Net::SSH::AuthenticationFailed
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
        Timeout::timeout(10) do
          @rye_ssh.loop(0.3) { @rye_ssh.busy?; }
        end
      rescue SystemCallError, Timeout::Error => ex
        error "Disconnect timeout (was something still running?)"
      end
      
      debug "Closing connection to #{@rye_ssh.host}"
      @rye_ssh.close
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
    def run_command(*args)
      debug "run_command with keys: #{Rye.keys.inspect}"
      
      cmd, args = prep_args(*args)
      
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
        cmd_internal = [cwd, cmd_internal].join(' && ')
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
        
        stdout, stderr, ecode, esignal = net_ssh_exec!(cmd_internal)
        
        rap.add_stdout(stdout || '')
        rap.add_stderr(stderr || '')
        rap.add_exit_code(ecode)
        rap.exit_signal = esignal
        
        #info "stdout: #{rap.stdout}"
        #info "stderr: #{rap.stderr}"
        #info "exit_code: #{rap.exit_code}"
        
        # It seems a convention for various commands to return -1
        # when something only mildly concerning happens. ls even 
        # returns -1 for apparently no reason sometimes. In any
        # case, the real errors are the ones greater than zero
        raise Rye::CommandError.new(rap) if ecode != 0
        
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
        else
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
      cmd = args.shift
      
      # Symbols to switches. :l -> -l, :help -> --help
      args.collect! do |a|
        if a.is_a?(Symbol)
          a = (a.to_s.size == 1) ? "-#{a}" : a.to_s
        end
        a
      end
      [cmd, args]
    end
    
    # Executes +command+ via SSH
    # Returns an Array with 4 elements: [stdout, stderr, exit code, exit signal]
    # NOTE: This method needs to be replaced to fully support interactive 
    # commands. This implementation is weird because it's getting just STDOUT and
    # STDERR responses (check value of "type"). on_data and on_extended_data method
    # hooks are not used. See the following threads for implementation ideas:
    #
    # http://www.ruby-forum.com/topic/141814
    # http://www.ruby-forum.com/topic/169997
    #
    def net_ssh_exec!(command)

      block ||= Proc.new do |channel, type, data, tt|
        
        channel[:stdout] ||= ""
        channel[:stderr] ||= ""
        
        
        if type == :stderr
          # NOTE: Use sudo to test this since it prompts for a passwords. 
          # Use sudo -K to kill the user's timestamp (ask for a password every time)
          if data =~ /password:/i
            ret = Annoy.get_user_input("Password: ", '*')
            raise Rye::NoPassword if ret.nil?
            channel.send_data "#{ret}\n"
          else
            channel[:stderr] << data 
          end

          # If someone tries to open an interactive ssh session
          # through a regular Rye::Box command, Net::SSH will
          # return the following error and appear to hang. We
          # catch it and raise the appropriate exception.
          raise Rye::NoPty if data =~ /Pseudo-terminal will not/
        elsif type == :stdout
          if data =~ /Select gem to uninstall/i
            puts data
            ret = Annoy.get_user_input('')
            raise "No input given" if ret.nil?
            channel.send_data "#{ret}\n"
          else
            channel[:stdout] << data
          end
        end
        
      end
      
      channel = @rye_ssh.exec(command, &block)
      
      channel.on_request("exit-status") do |ch, data|
        # Anything greater than 0 is an error
        channel[:exit_code] = data.read_long
      end
      channel.on_request("exit-signal") do |ch, data|
        # This should be the POSIX SIGNAL that ended the process
        channel[:exit_signal] = data.read_long
      end
      
      channel.wait  # block until we get a response
      channel.request_pty do |ch, success|
        raise Rye::NoPty if !success
      end
      
      ## I'm getting weird behavior with exit codes. Sometimes
      ## a command which usually returns an exit code will not
      ## return one the next time it's run. The following crap
      ## was from the debugging.
      ##Kernel.sleep 5
      ###channel.close
      #channel.eof!
      ##p [:active, channel.active?]
      ##p [:closing, channel.closing?]
      ##p [:eof, channel.eof?]
      
      channel[:exit_code] ||= 0
      channel[:exit_code] &&= channel[:exit_code].to_i
      channel[:stderr].gsub!(/bash: line \d+:\s+/, '') if channel[:stderr]
      
      [channel[:stdout], channel[:stderr], channel[:exit_code], channel[:exit_signal]]
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
          files.collect! { |file| Dir.glob File.expand_path(file) }
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
      
      info "#{direction.to_s} to: #{target}"
      debug "FILES: " << files.join(', ')
      
      # Make sure the target directory exists. We can do this only when
      # there's more than one file because "target" could be a file name
      if files.size > 1 && !target.is_a?(StringIO)
        debug "CREATING TARGET DIRECTORY: #{target}"
        self.mkdir(:p, target) unless self.file_exists?(target)
      end
      
      Net::SCP.start(@rye_host, @rye_opts[:user], @rye_opts || {}) do |scp|
        transfers = []
        prev = ""
        files.each do |file|
          debug file.to_s
          prev = ""
          transfers << scp.send(direction, file, target, :recursive => recursive)  do |ch, n, s, t|
            line = "%-50s %6d/%-6d bytes" % [n, s, t]
            spaces = (prev.size > line.size) ? ' '*(prev.size - line.size) : ''
            pinfo "%s %s \r" % [line, spaces] # update line: "file: sent/total"
            @rye_info.flush if @rye_info        # make sure every line is printed
            prev = line
          end
        end
        transfers.each { |t| t.wait }   # Run file transfers in parallel
        pinfo (' '*prev.size) << "\r"
        info $/
      end
      
      target.is_a?(StringIO) ? target : nil
    end
    

  end
end


