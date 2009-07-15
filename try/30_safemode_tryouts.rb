group "Safe Mode"
library :rye, 'lib'

tryouts "Basics" do
  drill "enabled by default" do
    Rye::Box.new.safe?
  end  
  drill "can be diabled when created", false do
    r = Rye::Box.new 'localhost', :safe => false
    r.safe?
  end
  drill "can be disabled on the fly", false do
    r = Rye::Box.new
    r.disable_safe_mode
    r.safe?
  end
end

tryouts "Safe Mode Enabled" do
  dream :exception, Rye::CommandNotFound
  drill "cannot execute arbitrary commands" do
    r = Rye::Box.new 'localhost'
    r.execute '/bin/ls'
  end
  
  dream :exception, Rye::CommandNotFound
  drill "cannot remove files" do
    r = Rye::Box.new 'localhost'
    file = "/tmp/tryouts-#{rand.to_s}"
    r.touch file
    stash :file_exists, r.file_exists?(file)
    r.rm file
  end
  
  dream :exception, Rye::CommandError
  drill "can use file globs" do
    r = Rye::Box.new 'localhost'
    r.ls '/bin/**'
  end
  
  dream :exception, Rye::CommandError
  drill "can use a tilda" do
    r = Rye::Box.new 'localhost'
    r.ls '~'
  end
end

tryouts "Safe Mode Disabled" do
  dream :empty?, false
  drill "can execute arbitrary commands" do
    r = Rye::Box.new 'localhost', :safe => false
    r.execute '/bin/ls'
  end
  
  drill "can remove files", false do
    r = Rye::Box.new 'localhost', :safe => false
    file = "/tmp/tryouts-#{rand.to_s}"
    r.touch file
    stash :file_exists, r.file_exists?(file)
    r.rm file
    r.file_exists? file
  end
  
  dream :empty?, false
  drill "can use file globs" do
    r = Rye::Box.new 'localhost', :safe => false
    r.ls '/bin/**'
  end
  
  dream :empty?, false
  drill "can use a tilda" do
    r = Rye::Box.new 'localhost', :safe => false
    r.ls '~'
  end
end



