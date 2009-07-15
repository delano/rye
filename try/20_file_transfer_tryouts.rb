

library :rye, 'lib'

local_sandbox = File.join(Rye.sysinfo.tmpdir, 'rye-tryouts')

tryouts "File transfer" do
  
  setup do
    Rye::Cmd.add_command :rm
  end
  clean do
    Rye::Cmd.remove_command :rm
  end
  
  drill "sandbox should not exist", false do
    File.exists? local_sandbox
  end
  
  drill "create sandbox", true do
    lbox = Rye::Box.new
    lbox.mkdir local_sandbox
    lbox.file_exists? local_sandbox
  end
  
  drill "upload file", true do
    lbox = Rye::Box.new
    lbox.file_upload 'README.rdoc', local_sandbox
    lbox.file_exists? local_sandbox
  end
  
  drill "download file", true do
    lbox = Rye::Box.new
    downloaded_file = File.join(Rye.sysinfo.tmpdir, 'downloaded.file')
    lbox.file_download File.join(local_sandbox, 'README.rdoc'), downloaded_file 
    ret = lbox.file_exists? downloaded_file
    lbox.rm downloaded_file
    ret
  end
  
  dream :read, ''
  dream :class, StringIO
  drill "download to StringIO" do
    lbox = Rye::Box.new
    lbox.file_download File.join(local_sandbox, 'README.rdoc')
  end
  
  drill "downloaded StringIO matches file content", true do
    lbox = Rye::Box.new
    file = lbox.file_download File.join(local_sandbox, 'README.rdoc')
    file.rewind
    file.read == File.read(File.join(local_sandbox, 'README.rdoc'))
  end
  
  
  drill "destroy sandbox", false do
    lbox = Rye::Box.new
    Rye::Cmd.add_command :rm
    lbox.rm :r, :f, local_sandbox
    lbox.file_exists? local_sandbox
  end
end

