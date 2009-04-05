

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
    attr_accessor :exit_code
    attr_accessor :exit_signal
    
    # * +obj+ an instance of Rye::Box or Rye::Set
    # * +args+ anything that can sent to Array#new
    def initialize(obj, *args)
      @obj = obj
      super *args
    end
    
    alias :box :obj
    alias :set :obj
    
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
    
    # Returns the first element if there it's the only
    # one, otherwise the value of Array#to_s
    def to_s
      return self.first if self.size == 1
      return "" if self.size == 0
      super
    end
    
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