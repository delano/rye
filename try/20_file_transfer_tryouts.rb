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
@lbox.file_exists? @local_sandbox
#=> true

## download file
downloaded_file = File.join(Rye.sysinfo.tmpdir, 'downloaded.file')
@lbox.file_download File.join(@local_sandbox, 'README.rdoc'), downloaded_file 
ret = @lbox.file_exists? downloaded_file
@lbox.rm downloaded_file
ret
#=> true

## download to StringIO
ret = @lbox.file_download File.join(@local_sandbox, 'README.rdoc')
ret.class
#=> StringIO

## downloaded StringIO matches file content
file = @lbox.file_download File.join(@local_sandbox, 'README.rdoc')
file.rewind
file.read == File.read(File.join(@local_sandbox, 'README.rdoc'))
#=> true


## destroy sandbox
Rye::Cmd.add_command :rm
@lbox.rm :r, :f, @local_sandbox
@lbox.file_exists? @local_sandbox
#=> false


Rye::Cmd.remove_command :rm
