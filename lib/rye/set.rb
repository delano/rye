# vim: set sw=2 ts=2 :

module Rye

  # = Rye::Set
  #
  #
  class Set
    attr_reader :name
    attr_reader :boxes
    attr_reader :opts

      # Run commands in parallel? A Boolean value. Default: false.
    attr_accessor :parallel


    # * +name+ The name of the set of machines
    # * +opts+ a hash of optional arguments
    #
    # The +opts+ hash is used as defaults for all for all Rye::Box objects.
    # All args supported by Rye::Box are available here with the addition of:
    #
    # * :parallel => run the commands in parallel? true or false (default).
    #
    def initialize(name='default', opts={})
      @name = name
      @boxes = []

      # These opts are use by Rye::Box and also passed to Net::SSH
      @opts = {
        :parallel => false,
        :user => Rye.sysinfo.user,
        :safe => true,
        :port => 22,
        :keys => [],
        :password => nil,
        :proxy => nil,
        :debug => nil,
        :error => STDERR,
      }.merge(opts)

      @parallel = @opts.delete(:parallel) # Rye::Box doesn't have :parallel

      @safe = @opts[:safe]
      @debug = @opts[:debug]
      @error = @opts[:error]

      @opts[:keys] = [@opts[:keys]].flatten.compact

      add_keys(@opts[:keys])
    end

    def opts; @opts; end
    def user; (@opts || {})[:user]; end
    def root?; user.to_s == "root" end

    # * +boxes+ one or more boxes. Rye::Box objects will be added directly
    # to the set. Hostnames will be used to create new instances of Rye::Box
    # and those will be added to the list.
    def add_box(*boxes)
      boxes = boxes.flatten.compact
      @boxes += boxes.collect do |box|
        box = Rye::Box.new(box, @opts) if box.is_a?(String)
        box.add_keys(@keys)
        box
      end
      self
    end
    alias :add_boxes :add_box

    # Add one or more private keys to each box. Also stores key paths
    # in the set so when new boxes are added they will get the same keys,
    # * +additional_keys+ is a list of file paths to private keys
    # Returns the instance of Rye::Set
    def add_keys(*additional_keys)
      additional_keys = additional_keys.flatten.compact
      @opts[:keys] ||= []
      @opts[:keys] += additional_keys
      @opts[:keys].uniq!
      @boxes.each do |box|
        box.add_keys *additional_keys
      end
      self
    end
    alias :add_key :add_keys

    def remove_keys(*keys)
      @opts[:keys] ||= []
      @opts[:keys] -= keys.flatten.compact
      @boxes.each do |box|
        box.remove_keys keys.flatten.compact
      end
      self
    end
    alias :remove_key :remove_keys

    # Add an environment variable. +n+ and +v+ are the name and value.
    # Returns the instance of Rye::Set
    def setenv(n, v)
      run_command(:setenv, n, v)
      self
    end
    alias :setenvironment_variable :setenv

    # See Rye.keys
    def keys
      Rye.keys
    end

    def to_s
      "%s:%s" % [self.class.to_s, @name]
    end

    def inspect
      a = [self.class.to_s, @name, @parallel, @opts.inspect, @boxes.inspect]
      %q{#<%s:%s parallel=%s opts=%s boxes=%s>} % a
    end

    # See Rye::Box.[]
    def [](key=nil)
      run_command(:cd, key)
      self
    end
#    alias :cd :'[]'  # fix for jruby
    def cd(key=nil)
      run_command(:cd, key)
      self
    end

    # Are there any boxes in this set?
    def empty?
      @boxes.nil? || @boxes.empty?
    end

    # Catches calls to Rye::Box commands. If +meth+ is the name of an
    # instance method defined in Rye::Cmd then we call it against all
    # the boxes in +@boxes+. Otherwise this method raises a
    # Rye::CommandNotFound exception. It will also raise a Rye::NoBoxes
    # exception if this set has no boxes defined.
    #
    # Returns a Rye::Rap object containing the responses from each Rye::Box.
    def method_missing(meth, *args, &block)
      # Ruby 1.8 populates Module.instance_methods with Strings. 1.9 uses Symbols.
      meth = (Rye.sysinfo.ruby[1] == 8) ? meth.to_s : meth.to_sym
      raise Rye::NoBoxes if @boxes.empty?
      if @safe
        raise Rye::CommandNotFound, meth.to_s unless Rye::Box.instance_methods.member?(meth)
      end
      run_command(meth, *args, &block)
    end

  private

    # Determines whether to call the serial or parallel method, then calls it.
    def run_command(meth, *args, &block)
      runner = @parallel ? :run_command_parallel : :run_command_serial
      self.send(runner, meth, *args, &block)
    end


    # Run the command on all boxes in parallel
    def run_command_parallel(meth, *args, &block)
      debug "P: #{meth} on #{@boxes.size} boxes (#{@boxes.collect {|b| b.host }.join(', ')})"
      threads = []

      raps = Rye::Rap.new(self)
      (@boxes || []).each do |box|
        threads << Thread.new do
          Thread.current[:rap] = box.send(meth, *args, &block) # Store the result in the thread
        end
      end

      threads.each do |t|
        Kernel.sleep 0.03 # Give the thread some breathing room

        begin
          t.join # Wait for the thread to finish
        rescue Exception => ex
          # Store the exception in the result
          raps << Rap.new(self, [ex])
          next
        end

        raps << t[:rap] # Grab the result
      end

      raps
    end


    # Run the command on all boxes in serial
    def run_command_serial(meth, *args, &block)
      debug "S: #{meth} on #{@boxes.size} boxes (#{@boxes.collect {|b| b.host }.join(', ')})"
      raps = Rye::Rap.new(self)
      (@boxes || []).each do |box|
        raps << box.send(meth, *args, &block)
      end
      raps
    end

    def debug(msg); @debug.puts msg if @debug; end
    def error(msg); @error.puts msg if @error; end

  end

end
