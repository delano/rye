require 'rye'

rbox = Rye::Box.new 'api.solutious.com', :user => 'proto'
#rbox.bash do 
#  ret = sudo 'whoami'
#  sudo :k
#  p [:m, ret]
#end

#rbox.bash

rbox.irb :I, 'blamestella.com/lib', :r, 'blamestella'

#rbox.sh