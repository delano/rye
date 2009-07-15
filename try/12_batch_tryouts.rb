
group "Basics"
library :rye, 'lib'

tryouts "Rye::Box#batch" do
  
  clean do
    r = Rye::Box.new
    r.disable_safe_mode
    r.rm '/tmp/rye-*'
  end
  
  drill "can execute commands in a batch" do
    r = Rye::Box.new
    file = "/tmp/rye-#{rand.to_s}"
    r.batch do
      touch file
    end
    r.file_exists? file
  end
  
  drill "a batch can take arguments" do
    r = Rye::Box.new
    file = r.batch("/tmp/rye-#{rand.to_s}") do |f|
      touch f
      f
    end
    r.file_exists? file
  end
  
end