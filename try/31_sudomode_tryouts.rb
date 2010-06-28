group "Sudo Mode"
library :rye, 'lib'

tryouts "Basics" do
  drill "disabled by default", false do
    Rye::Box.new.sudo?
  end  
  drill "can be enabled when created", true do
    r = Rye::Box.new 'localhost', :sudo => true
    r.sudo?
  end
  drill "can be enabled on the fly", true do
    r = Rye::Box.new
    r.enable_sudo
    r.sudo?
  end
end

tryouts "Sudo Mode Enabled" do
  dream :exception, Rye::CommandError
  drill "Doesn't handle the password prompt (to be fixed)" do
    r = Rye::Box.new 'localhost', :sudo => true
    r.ls
  end
  
end

tryouts "Sudo Mode Disabled" do
  
end



