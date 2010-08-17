require 'rye'

@local_sandbox = File.join(Rye.sysinfo.tmpdir, 'rye-tryouts')
@rendered = "#{@local_sandbox}/rendered.txt"
@lbox = Rye::Box.new 'localhost', :info => STDOUT
Rye::Cmd.add_command :rm
@lbox.rm :r, :f, @local_sandbox

## sandbox should not exist
File.exists? @local_sandbox
#=> false

## create sandbox
@lbox.mkdir :p, @local_sandbox
@lbox.file_exists? @local_sandbox
#=> true

## upload template
@lbox.template_write "<%= uname :a %>", @rendered
@lbox.file_exists? @rendered
#=> true

## upload template with vars
@lbox.template_write "<%= uname :a %>", @rendered
@lbox.file_exists? @rendered
#=> true


## destroy sandbox
#@lbox = Rye::Box.new
#Rye::Cmd.add_command :rm
#
#@lbox.file_exists? @local_sandbox
##=> false


Rye::Cmd.remove_command :rm
