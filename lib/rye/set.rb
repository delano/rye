module Rye
  
  # = Rye::Set
  #
  #
  class Set
    attr_reader :name
    attr_reader :boxes
    
    # * +name+ The name of the set of machines
    # * +opts+ a hash of optional arguments used as defaults for all
    # for all Rye::Box objects. The options are:
    #
    # * :parallel => run the commands in parallel? true (default) or false.
    # * :user => the username to connect as. Default: the current user. 
    # * :keypairs => one or more private key file paths (passwordless login)
    # * :debug => an IO object to print Rye::Box debugging info to
    # * :error => an IO object to print Rye::Box errors to. Default: STDERR
    def initialize(name='default', opts={})
      @name = name
      @boxes = []
      
      @opts = {
        :parallel => true,
        :user => Rye.sysinfo.user, 
        :keypairs => [],
        :debug => STDOUT,
        :error => STDERR,
      }.merge(opts)
      
      @parallel = @opts.delete(:parallel) # Rye::Box doesn't have :parallel
      
      @debug = @opts[:debug]
      @error = @opts[:error]
      
      add_keys(opts[:keypairs])
    end
    
    # * +boxes+ one or more boxes. Rye::Box objects will be added directly 
    # to the set. Hostnames will be used to create new instances of Rye::Box 
    # and those will be added to the list. 
    def add_box(*boxes)
      boxes = boxes.flatten.compact 
      @boxes += boxes.collect do |box|
        box.is_a?(Rye::Box) ? box.add_keys(@keys) : Rye::Box.new(box, @opts)
      end
      @boxes
    end
    alias :add_boxes :add_box
    
    # Add one or more private keys to the SSH Agent. 
    # * +additional_keys+ is a list of file paths to private keys
    # Returns the instance of Rye::Set
    def add_key(*additional_keys)
      additional_keys = [additional_keys].flatten.compact || []
      Rye.add_keys(additional_keys)
      self
    end
    alias :add_keys :add_key
    
    def add_env(n, v)
      run_command(:add_env, n, v)
      self
    end
    alias :add_environment_variable :add_env
    
    def keys
      Rye.keys
    end
    
    def [](key=nil)
      run_command(:cd, key)
      self
    end
    alias :cd :'[]'
    
    def method_missing(meth, *args)
      raise Rye::NoBoxes if @boxes.empty?
      raise Rye::CommandNotFound, meth.to_s unless @boxes.first.respond_to?(meth)
      run_command(meth, *args)
    end
    
  private
    
    def run_command(meth, *args)
      runner = @parallel ? :run_command_parallel : :run_command_serial
      self.send(runner, meth, *args)
    end
    
    def run_command_parallel(meth, *args)
      debug "P: #{meth} on #{@boxes.size} boxes (#{@boxes.collect {|b| b.host }.join(', ')})"
      threads = []
      
      raps = Rye::Rap.new(self)
      (@boxes || []).each do |box|
        threads << Thread.new do
          Thread.current[:rap] = box.send(meth, *args) # Store the result in the thread
        end
      end
      
      threads.each do |t| 
        sleep 0.01
        t.join            # Wait for the thread to finish
        raps << t[:rap]   # Grab the result
      end
      
      raps
    end
    
    def run_command_serial(meth, *args)
      debug "S: #{meth} on #{@boxes.size} boxes (#{@boxes.collect {|b| b.host }.join(', ')})"
      raps = Rye::Rap.new(self)
      (@boxes || []).each do |box|
        raps << box.send(meth, *args)
      end
      raps
    end
    
    def debug(msg); @debug.puts msg if @debug; end
    def error(msg); @error.puts msg if @error; end
    
    
  end
  
end