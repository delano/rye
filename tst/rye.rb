require 'rye'

rbox = Rye::Box.new 'localhost', :user => 'delano'
#rbox.bash do 
#  ls(:l, '/etc2') rescue nil
#  ls :l, '/etc'
#end

#rbox.bash

#rbox.irb :I, 'blamestella.com/lib', :r, 'blamestella' do
#  puts BS.sysinfo
#end

#rbox.sh