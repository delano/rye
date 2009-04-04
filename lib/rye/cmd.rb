
module Rye;
  
  # = Rye::Cmd
  #
  # This class contains all of the shell command methods
  # available to an instance of Rye::Box. For security and 
  # general safety, Rye only permits this whitelist of
  # commands by default. However, you're free to add methods
  # with mixins. 
  #
  #     require 'rye'
  #     module Rye::Box::Cmd
  #       def uptime; cmd("uptime"); end
  #       def sleep(seconds=1); cmd("sleep", seconds); end
  #       def special(*args); cmd("/your/special/command", args); end
  #     end
  #
  #     rbox = Rye::Box.new
  #     rbox.uptime   # => 11:02  up 8 days, 17:17, 2 users
  #
  module Cmd
    def wc(*args); cmd('wc', args); end
    def cp(*args); cmd("cp", args); end
    def mv(*args); cmd("mv", args); end
    def ls(*args); cmd('ls', args); end
    def rm(*args); cmd('rm', args); end
    def sh(*args); cmd('sh', args); end
    def env; cmd "env"; end
    def pwd(key=nil); cmd "pwd"; end
    def date(*args); cmd('date', args); end
    def ruby(*args); cmd('ruby', args); end
    def perl(*args); cmd('perl', args); end
    def bash(*args); cmd('bash', args); end
    def echo(*args); cmd('echo', args); end
    def sleep(seconds=1); cmd("sleep", seconds); end
    def touch(*args); cmd('touch', args); end
    def uname(*args); cmd('uname', args); end
    def mount; cmd("mount"); end
    def python(*args); cmd('python', args); end
    def uptime; cmd("uptime"); end
    def printenv(*args); cmd('printenv', args); end
    # Consider Rye.sysinfo.os == :unix
  end

end