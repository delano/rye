
module Rye; class Box;
  
  # = Rye::Box::Commands
  #
  # This class contains all of the shell command methods
  # available to an instance of Rye::Box. For security and 
  # general safety, Rye only permits this whitelist of
  # commands by default. However, you're free to add methods
  # with mixins. 
  #
  #     require 'rye'
  #     module Rye::Box::Commands
  #       def uptime; command("uptime"); end
  #       def sleep(seconds=1); command("sleep", seconds); end
  #       def special(*args); command("/your/special/command", args); end
  #     end
  #
  #     rbox = Rye::Box.new
  #     rbox.uptime   # => 11:02  up 8 days, 17:17, 2 users
  #
  module Commands
    def wc(*args); command('wc', args); end
    def cp(*args); command("cp", args); end
    def mv(*args); command("mv", args); end
    def ls(*args); command('ls', args); end
    def env; command "env"; end
    def pwd(key=nil); command "pwd"; end
    def date(*args); command('date', args); end
    def echo(*args); command('echo', args); end
    def sleep(seconds=1); command("sleep", seconds); end
    def mount; command("mount"); end
    def uptime; command("uptime"); end
  end

end; end