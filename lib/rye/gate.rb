
require 'net/ssh/gateway'

# silly overrides
class Net::SSH::Gateway
    def host ; @session.host ; end
    def busy? ; @session.busy? ; end
end


module Rye
  DEBUG = false unless defined?(Rye::DEBUG)

  ## TODO decide whether, or how, to have means by which
  ##      to let a Rye::Gate have a :via attribute, so that 
  ##      you could hop to a host that is more than one layer removed.
  class Gate

    # A Hash. The keys are exception classes, the values are Procs to execute
    def exception_hook=(val); @rye_exception_hook = val; end

    # * +host+ The hostname to connect to. Default: localhost.
    # * +user+ The username to connect as. Default: SSH config file or current shell user.
    # * +opts+ a hash of optional arguments.
    #
    # The +opts+ hash excepts the following keys:
    #
    # * :port => remote server ssh port. Default: SSH config file or 22
    # * :keys => one or more private key file paths (passwordless login)
    # * :via => the Rye::Gate to access this host through
    # * :info => an IO object to print Rye::Box command info to. Default: nil
    # * :debug => an IO object to print Rye::Box debugging info to. Default: nil
    # * :error => an IO object to print Rye::Box errors to. Default: STDERR
    # * :getenv => pre-fetch +host+ environment variables? (default: true)
    # * :password => the user's password (ignored if there's a valid private key)
    # * :templates => the template engine to use for uploaded files. One of: :erb (default)
    # * :sudo => Run all commands via sudo (default: false)
    #
    # NOTE: +opts+ can also contain any parameter supported by 
    # Net::SSH.start that is not already mentioned above.
    #
    def initialize(host, opts={})
      ssh_opts = ssh_config_options(host)
      @rye_exception_hook = {}
      @rye_host = host
      
      if opts[:user]
        @rye_user = opts[:user]
      else
        @rye_user = ssh_opts[:user] || Rye.sysinfo.user
      end
      
      # These opts are use by Rye::Box and also passed to
      # Net::SSH::Gateway (and Net::SSH)
      @rye_opts = {
        :port => ssh_opts[:port],
        :keys => Rye.keys,
        :via => nil,
        :info => nil,
        :debug => nil,
        :error => STDERR,
        :getenv => true,
        :templates => :erb,
        :quiet => false
      }.merge(opts)

      # Close the SSH session before Ruby exits. This will do nothing
      # if disconnect has already been called explicitly. 
      at_exit { self.disconnect }

      # @rye_opts gets sent to Net::SSH so we need to remove the keys
      # that are not meant for it. 
      @rye_via, @rye_debug = @rye_opts.delete(:via), @rye_opts.delete(:via)
      @rye_info, @rye_error = @rye_opts.delete(:info), @rye_opts.delete(:error)
      @rye_getenv = {} if @rye_opts.delete(:getenv) # Enable getenv with a hash
      @rye_ostype, @rye_impltype = @rye_opts.delete(:ostype), @rye_opts.delete(:impltype)
      @rye_quiet, @rye_sudo = @rye_opts.delete(:quiet), @rye_opts.delete(:sudo)
      @rye_templates = @rye_opts.delete(:templates)
      
      # Store the state of the terminal 
      @rye_stty_save = `stty -g`.chomp rescue nil
      
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
      
      # From: capistrano/lib/capistrano/cli.rb
      STDOUT.sync = true # so that Net::SSH prompts show up
      
      debug "ssh-agent info: #{Rye.sshagent_info.inspect}"
      debug @rye_opts.inspect

    end
    
    # Parse SSH config files for use with Net::SSH
    def ssh_config_options(host)
      return Net::SSH::Config.for(host)
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
      debug "Opening connection to #{@rye_host} as #{@rye_user}"
      highline = HighLine.new # Used for password prompt
      retried = 0
      @rye_opts[:keys].compact!  # A quick fix in Windows. TODO: Why is there a nil?
      begin
        @rye_ssh = Net::SSH::Gateway.start(@rye_host, @rye_user, @rye_opts || {}) 
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
          STDERR.puts "Passwordless login failed for #{@rye_user}"
          @rye_opts[:password] = highline.ask("Password: ") { |q| q.echo = '' }.strip
          @rye_opts[:auth_methods] ||= []
          @rye_opts[:auth_methods].push *['keyboard-interactive', 'password']
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
      return unless @rye_ssh && @rye_ssh.active?
      begin
        if @rye_ssh.busy?;
          info "Is something still running? (ctrl-C to exit)"
          Timeout::timeout(10) do
            @rye_ssh.loop(0.3) { @rye_ssh.busy?; }
          end
        end
        debug "Closing connection to #{@rye_ssh.host}"
        @rye_ssh.shutdown!
      rescue SystemCallError, Timeout::Error => ex
        error "Disconnect timeout"
      rescue Interrupt
        debug "Exiting..."
      end
    end
    
  end

end
