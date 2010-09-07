require 'rye'

@local_sandbox = File.join(Rye.sysinfo.tmpdir, 'rye-tryouts')
@lbox = Rye::Box.new 'localhost'
Rye::Cmd.add_command :rm


## sandbox should not exist
@lbox.file_exists? @local_sandbox
#=> false

## create sandbox
@lbox.mkdir :p, @local_sandbox
@lbox.file_exists? @local_sandbox
#=> true

## upload file
@lbox.file_upload 'README.rdoc', @local_sandbox
@lbox.file_exists? File.join(@local_sandbox, 'README.rdoc')
#=> true

## download file
@downloaded_file = File.join(Rye.sysinfo.tmpdir, 'localfile')
@lbox.file_download File.join(@local_sandbox, 'README.rdoc'), @downloaded_file 
@lbox.file_exists? @downloaded_file
#=> true

## download to StringIO
content = @lbox.file_download File.join(@local_sandbox, 'README.rdoc')
content.class
#=> StringIO

## downloaded StringIO matches file content
file = @lbox.file_download File.join(@local_sandbox, 'README.rdoc')
file.rewind
file.read == File.read(File.join(@local_sandbox, 'README.rdoc'))
#=> true

## destroy sandbox
@lbox.rm :r, :f, @local_sandbox
@lbox.file_exists? @local_sandbox
#=> false


@lbox.rm @downloaded_file
Rye::Cmd.remove_command :rm
