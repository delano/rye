require 'rye'

  
## can execute commands in a batch
r = Rye::Box.new
file = "/tmp/rye-#{rand.to_s}"
r.batch do
  touch file
end
r.file_exists? file
#=> true

## a batch can take arguments
r = Rye::Box.new
file = r.batch("/tmp/rye-#{rand.to_s}") do |f|
  touch f
  f
end
r.file_exists? file
#=> true



r = Rye::Box.new
r.disable_safe_mode
r.rm '/tmp/rye-*'
