require 'rye'

rbox = Rye::Box.new 'localhost', :user => 'delano'
rbox.bash do 
  ret = sudo 'whoami'
  sudo :k
  p [:m, ret]
end

#rbox.bash
