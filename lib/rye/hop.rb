# vim : set sw=2 ts=2 :

require 'socket'

module Rye
  DEBUG = false unless defined?(Rye::DEBUG)

  # = Rye::Hop
  #
  # The Rye::Hop class represents a machine. 
  # This class allows boxes to by accessed via it.
  #
  #     rhop = Rye::Hop.new('firewall.lan')
  #     rbox = Rye::Box.new('filibuster', :via => rhop)
  #     rbox.uptime     # => 20:53  up 1 day,  1:52, 4 users
  #
  # Or
  #
  #     rbox = Rye::Box.new('filibuster', :via => 'firewall.lan')
  #
  #--
  # * When anything confusing happens, enable debug in initialize
  # by passing :debug => STDERR. This will output Rye debug info
  # as well as Net::SSH info. This is VERY helpful for figuring
  # out why some command is hanging or otherwise acting weird. 
  # * If a remote command is hanging, it's probably because a
  # Net::SSH channel is waiting on_extended_data (a prompt). 
  #++
  class Hop

    # The maximum port number that the gateway will attempt to use to forward
    # connections from.
    MAX_PORT = 65535

    # The minimum port number that the gateway will attempt to use to forward
    # connections from.
    MIN_PORT = 1024

    def host; @rye_host; end
    def opts; @rye_opts; end
    def user; @rye_user; end
    def root?; user.to_s == "root" end
    
    def nickname; @rye_nickname || host; end
    def via; @rye_via; end

    def nickname=(val); @rye_nickname = val; end
    def host=(val); @rye_host = val; end
    def opts=(val); @rye_opts = val; end

    
    def via?; !@rye_via.nil?; end
    def info?; !@rye_info.nil?; end
    def debug?; !@rye_debug.nil?; end
    def error?; !@rye_error.nil?; end
    

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
    # * :via => the Rye::Hop to access this host through
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

      @next_port = MAX_PORT

      # Close the SSH session before Ruby exits. This will do nothing
      # if disconnect has already been called explicitly. 
      at_exit { self.disconnect }

      # Properly handle whether the opt :via is a +Rye::Hop+ or a +String+
      # and does nothing if nil
      via_hop(@rye_opts.delete(:via))

      # @rye_opts gets sent to Net::SSH so we need to remove the keys
      # that are not meant for it. 
      @rye_safe, @rye_debug = @rye_opts.delete(:safe), @rye_opts.delete(:debug)
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
    def via_hop(*hops)
      hops = hops.flatten.compact 
      if hops.first.nil?
        return @rye_via
      elsif hops.first.is_a?(Rye::Hop)
        @rye_via = hops.first
      elsif hops.first.is_a?(String)
        hop = hops.shift
        if hops.first.is_a?(Hash)
          @rye_via = Rye::Hop.new(hop, hops.first)
        else
          @rye_via = Rye::Hop.new(hop)
        end
      end
      disconnect
      self
    end

    # instance method, that will setup a forward, and
    # return the port used
    def fetch_port(host, port = 22, localport = nil)
      connect unless @rye_ssh
      if localport.nil?
        port_used = next_port
      else
        port_used = localport
      end
      # i would like to check if the port and host 
      # are already an active_locals forward, but that 
      # info does not get returned, and trusting the localport
      # is not enough information, so lets just set up a new one
      @rye_ssh.forward.local(port_used, host, port)
      return port_used
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
          @rye_ssh = Net::SSH.start("localhost", @rye_user, @rye_opts.merge(:port => @rye_localport) || {}) 
        else
          @rye_ssh = Net::SSH.start(@rye_host, @rye_user, @rye_opts || {}) 
        end
        debug "starting the port forward thread"
        port_loop
      rescue Net::SSH::HostKeyMismatch => ex
        STDERR.puts ex.message
        print "\a" if @rye_info # Ring the bell
        if highline.ask("Continue? ").strip.match(/\Ay|yes|sure|ya\z/i)
          @rye_opts[:paranoid] = false
          retry
        else
          raise ex
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

    # Cancel the port forward on all active local forwards
    def remove_hops!
      return unless @rye_ssh && @rye_ssh.forward.active_locals.count > 0
      @rye_ssh.forward.active_locals.each {|fport, fhost| 
        @rye_ssh.forward.cancel_local(fport, fhost)
      }
      if !@rye_ssh.channels.empty?
        @rye_ssh.channels.each {|channel|
          channel[-1].close
        }
      end
      return @rye_ssh.forward.active_locals.count
    end
    
    # Close the SSH session  with +@rye_host+. This is called 
    # automatically at exit if the connection is open. 
    def disconnect
      return unless @rye_ssh && !@rye_ssh.closed?
      begin
        debug "removing active forwards"
        remove_hops!
        debug "killing port_loop @rye_port_thread"
        @rye_port_thread.kill
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
        error "Rye::Hop: Disconnect timeout (#{ex.message})"
        debug ex.backtrace
      rescue Interrupt
        debug "Exiting..."
      end
    end
    
    # See Rye.keys
    def keys; Rye.keys; end
    
    # Returns +user@rye_host+
    def to_s; '%s@rye_%s' % [user, @rye_host]; end
    
    def inspect
      %q{#<%s:%s name=%s cwd=%s umask=%s env=%s via=%s opts=%s keys=%s>} % 
      [self.class.to_s, self.host, self.nickname,
       @rye_current_working_directory, @rye_current_umask,
       (@rye_current_environment_variables || '').inspect,
       (@rye_via || '').inspect,
       self.opts.inspect, self.keys.inspect]
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
    
  private
    # Kicks off the thread that maintains the forwards
    # if additional +Rye::Box+es add this +Rye::Hop+ as their via,
    # it'll keep on trucking
    def port_loop
      connect unless @rye_ssh
      @active = true
      @rye_port_thread = Thread.new do
        while @active
          @rye_ssh.process(0.1)
        end
      end
    end

    # Grabs the next available port number and returns it.
    def next_port
      port = @next_port
      @next_port -= 1
      @next_port = MAX_PORT if @next_port < MIN_PORT
      # check if the port is in use, if so get the next_port
      begin
        TCPSocket.new '127.0.0.1', port
      rescue Errno::EADDRINUSE
        next_port()
      rescue Errno::ECONNREFUSED
        port
      else
        next_port()
      end
    end
      
    def debug(msg="unknown debug msg"); @rye_debug.puts msg if @rye_debug; end
    def error(msg="unknown error msg"); @rye_error.puts msg if @rye_error; end
    def pinfo(msg="unknown info msg"); @rye_info.print msg if @rye_info; end
    def info(msg="unknown info msg"); @rye_info.puts msg if @rye_info; end
    
  end

end

