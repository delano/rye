require 'rye'

@local_sandbox = File.join(Rye.sysinfo.tmpdir, 'rye-tryouts')
Rye::Cmd.add_command :rm


## sandbox should not exist
File.exists? @local_sandbox
#=> false

## create sandbox
lbox = Rye::Box.new
lbox.mkdir @local_sandbox
lbox.file_exists? @local_sandbox
#=> true

## upload file
lbox = Rye::Box.new
lbox.file_upload 'README.rdoc', @local_sandbox
lbox.file_exists? @local_sandbox
#=> true

## download file
lbox = Rye::Box.new
downloaded_file = File.join(Rye.sysinfo.tmpdir, 'downloaded.file')
lbox.file_download File.join(@local_sandbox, 'README.rdoc'), downloaded_file 
ret = lbox.file_exists? downloaded_file
lbox.rm downloaded_file
ret
#=> true

## download to StringIO" do
lbox = Rye::Box.new
ret = lbox.file_download File.join(@local_sandbox, 'README.rdoc')
ret.class
#=> StringIO

## downloaded StringIO matches file content
lbox = Rye::Box.new
file = lbox.file_download File.join(@local_sandbox, 'README.rdoc')
file.rewind
file.read == File.read(File.join(@local_sandbox, 'README.rdoc'))
#=> true


## destroy sandbox
lbox = Rye::Box.new
Rye::Cmd.add_command :rm
lbox.rm :r, :f, @local_sandbox
lbox.file_exists? @local_sandbox
#=> false


Rye::Cmd.remove_command :rm
