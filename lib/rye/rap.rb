# vim: set sw=2 ts=2 :

module Rye;
  
  # Rye::Rap
  #
  # This class is a modified Array which is returned by
  # all command methods. The command output is split
  # by line into an instance of this class. If there is
  # only a single element it will act like a String. 
  #
  # This class also contains a reference to the instance
  # of Rye::Box or Rye::Set that the command was executed 
  # on. 
  #
  class Rap < Array 
     # A reference to the Rye object instance the command
     # was executed by (Rye::Box or Rye::Set)
    attr_reader :obj
    
     # An array containing any STDERR output 
    attr_reader :stderr
    attr_reader :exit_status
      # Only populated when calling via Rye::Shell 
    attr_reader :pid 
    attr_accessor :exit_signal
    
      # The command that was executed. 
    attr_accessor :cmd
    
    # * +obj+ an instance of Rye::Box or Rye::Set
    # * +args+ anything that can sent to Array#new
    def initialize(obj, *args)
      @obj = obj
      @exit_status = -1
      @stderr = []
      super *args
    end
    
    alias :box :obj
    alias :set :obj
    
    def inspect
      "[%s, %s, %s, %s]" % [self.join("").tr("\r", ''), @stderr.join("; ").tr("\r", ''), exit_status, exit_signal]
    end
    
    # Returns a reference to the Rye::Rap object (which 
    # acts like an Array that contains the STDOUT from the
    # command executed over SSH). This is available to 
    # maintain consistency with the stderr method. 
    def stdout
      self
    end
    
    # Add STDERR output from the command executed via SSH. 
    def add_stderr(*args)
      args = args.flatten.compact
      args = args.first.split($/) if args.size == 1
      @stderr ||= []
      @stderr << args
      @stderr.flatten!
      self
    end
    
    # Add STDOUT output from the command executed via SSH. 
    # This is available to maintain consistency with the 
    # add_stderr method. Otherwise there's no need to use
    # this method (treat the Rye::Rap object like an Array).
    def add_stdout(*args)
      args = args.flatten.compact
      args = args.first.split($/) if args.size == 1
      self << args
      self.flatten!
    end
    
    # Parse the exit code. 
    # * +code+ an exit code string or integer or Process::Status object
    # For example, when running a command via Rye.shell, this method 
    # is send $? which is Process::Status object. Via Rye::Box.run_command
    # it's just an exit code returned by Net::SSH. 
    #
    # In JRuby, if +code+ is a Process::Status object, @pid will be 
    # set to -1 (JRuby doesn't return the pid).   
    #
    # Returns the exit code as an Integer. 
    def add_exit_status(code)
      code = 0 if code.nil?
      if code.is_a?(Process::Status)
        @exit_status = code.exitstatus.to_i
        @pid = Rye.sysinfo.vm == :java ? '-1' : code.pid
      else
        @exit_status = code.to_i
      end
    end
    def code; @exit_status; end
    
    # Returns the first element if there's only the
    # one, an empty String if there's none. Returns
    # the value of self.join($/) otherwise. 
    def to_s; self.join $/; end
    
    # Output STDOUT content to (remote) +path+ 
    # This works like a shell redirect so the file contents are 
    # cleared before outputting. 
    # 
    #     rbox.ps('aux') > 'processes.log'
    #
    def >(path)
      self.obj.unsafely { rm path }
      self.obj.file_append(path, self)
    end
    
    # Output STDOUT content to (remote) +path+ 
    # This works like a shell redirect so if the target file
    # exists the STDOUT content will be appended. 
    #
    #     rbox.ps('aux') >> 'processes.log'
    #
    def >>(path)
      self.obj.file_append(path, self)
    end
    
    
    
    # NOTE: This is broken!
    #def grep *args
    #  self.select do |boxrap|
    #    b = boxrap.grep(*args)
    #    b.empty? ? false : b
    #  end
    #end
    
    
    #---
    # If Box's shell methods return Rap objects, then 
    # we can do stuff like this
    # rbox.cp '/etc' | rbox2['/tmp']
    #def |(other)
    #  puts "BOX1", self.join($/)
    #  puts "BOX2", other.join($/)
    #end
    #+++
    
  end
  
end
