require 'rye'

rbox = Rye::Box.new 'localhost', :user => 'delano'
rbox.bash do 
  ret = ls :l
  puts ret
end

rbox.bash
