

module Rye;
  
  # Rye::Rap
  #
  # This class is a modified Array which is returned by
  # all command methods. The commands output is split
  # by line into an instance of this class. If there is
  # only a single element it will act like a String. 
  #
  # This class also contains a reference to the instance
  # of Rye::Box that the command was executed on.
  #
  class Rap < Array 
     # A reference to the Rye object instance the command
     # was executed by (Rye::Box or Rye::Set)
    attr_reader :obj
    
    # * +obj+ an instance of Rye::Box or Rye::Set
    # * +args+ anything that can sent to Array#new
    def initialize(obj, *args)
      @obj = obj
      super *args
    end
    
    alias :box :obj
    alias :set :obj
    
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