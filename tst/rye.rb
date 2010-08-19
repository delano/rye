require 'rye'

rbox = Rye::Box.new 'localhost', :user => 'delano'
rbox.bash do 
  ls(:l, '/etc2') rescue nil
  puts ls :l, '/etc'
end

#rbox.bash

#rbox.irb :I, '/Users/delano/Projects/private/www.blamestella.com/lib', :r, 'blamestella' 

#rbox.sh