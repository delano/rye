require 'rye'


## knows dirs exist
lbox = Rye::Box.new
lbox.file_exists? '/etc'
#=> true

## knows files exist
lbox = Rye::Box.new 'localhost'
lbox.file_exists? '/etc/hosts'
#=> true
