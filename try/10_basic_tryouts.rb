
group "Basics"
library :rye, 'lib'

tryouts "Rye::Box" do
  
  drill "a Rye::Box instance defaults to localhost", 'localhost' do
    lbox = Rye::Box.new
    lbox.host
  end
  
  drill "can add commands", [false, true] do
    lbox = Rye::Box.new
    initially = lbox.can? :rm
    Rye::Cmd.add_command :rm
    ret = [initially, lbox.can?(:rm)]
  end
  
  drill "can remove commands", false do
    lbox = Rye::Box.new
    Rye::Cmd.remove_command :rm
    lbox.can?(:rm)
  end
  
  dream :class, Rye::Rap
  drill "returns a Rye::Rap object" do
    Rye::Box.new.uptime
  end
  
  dream `echo canadian`.chomp
  drill "returns the same stuff as backticks" do
    Rye::Box.new.echo("canadian").first
  end
  
  drill "starts in the home directory", ENV['HOME'] do
    lbox = Rye::Box.new.pwd.first
  end
  
end


tryouts "Environment variables" do
  
  drill "can get remote environment variables", true do
    lbox = Rye::Box.new
    File.exists? lbox.getenv['HOME']
  end
  
  drill "can set an environment variable", 'whiskey' do
    lbox = Rye::Box.new
    lbox.setenv( 'TIPPLE', 'whiskey')
    lbox.getenv[ 'TIPPLE' ]
  end
  
end