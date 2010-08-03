require 'rye'


## a Rye::Box instance defaults to localhost
lbox = Rye::Box.new
lbox.host
#=> 'localhost'

## can add commands
lbox = Rye::Box.new
initially = lbox.can? :rm
Rye::Cmd.add_command :rm
ret = [initially, lbox.can?(:rm)]
#=> [false, true]

## can remove commands
lbox = Rye::Box.new
Rye::Cmd.remove_command :rm
lbox.can?(:rm)
#=> false

## returns a Rye::Rap object
box = Rye::Box.new
box.uptime.class
#=> Rye::Rap

## returns the same stuff as backticks
Rye::Box.new.echo("canadian").first
#=> `echo canadian`.chomp

## starts in the home directory
lbox = Rye::Box.new.pwd.first
#=> ENV['HOME']

## can get remote environment variables
lbox = Rye::Box.new
File.exists? lbox.getenv['HOME']
#=> true

## can set an environment variable
lbox = Rye::Box.new
lbox.setenv( 'TIPPLE', 'whiskey')
lbox.getenv[ 'TIPPLE' ]
#=> 'whiskey'
