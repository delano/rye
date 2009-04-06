
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
  #       def special(*args); cmd("/your/special/command", args); end
  #     end
  #
  #     rbox = Rye::Box.new
  #     rbox.special        # => "your output"
  #
  module Cmd
    def wc(*args); cmd('wc', args); end
    def cp(*args); cmd("cp", args); end
    def mv(*args); cmd("mv", args); end
    def ls(*args); cmd('ls', args); end
    #def rm(*args); cmd('rm', args); end
    def ps(*args); cmd('ps', args); end
    def sh(*args); cmd('sh', args); end
    
    def env; cmd "env"; end
    def pwd; cmd "pwd"; end
    def svn(*args); cmd('svn', args); end
    def cvs(*args); cmd('cvs', args); end
    def git(*args); cmd('git', args); end
    def sed(*args); cmd('sed', args); end
    def awk(*args); cmd('awk', args); end
    def cat(*args); cmd('cat', args); end
    
    #def kill(*args); cmd('kill', args); end
    def sudo(*args); cmd('sudo', args); end
    def grep(*args); cmd('grep', args); end
    def date(*args); cmd('date', args); end
    def ruby(*args); cmd('ruby', args); end
    def perl(*args); cmd('perl', args); end
    def bash(*args); cmd('bash', args); end
    def echo(*args); cmd('echo', args); end
    def test(*args); cmd('test', args); end
    
    def mount; cmd("mount"); end
    def sleep(seconds=1); cmd("sleep", seconds); end
    def touch(*args); cmd('touch', args); end
    def uname(*args); cmd('uname', args); end
    
    def uptime; cmd("uptime"); end
    def python(*args); cmd('python', args); end
    def printenv(*args); cmd('printenv', args); end
    
  
    #  def copy_to(*boxes)
    #    p boxes
    #
    #    @scp = Net::SCP.start(@host, @opts[:user], @opts || {}) 
    #    #@ssh.is_a?(Net::SSH::Connection::Session) && !@ssh.closed?
    #     p @scp
    #  end
  
  
    #def copy_to(*args)
    #  args = [args].flatten.compact || []
    #  other = args.pop
    #  p other
    #end
    
    def exists?
      cmd("uptime");
    end
    
    # Consider Rye.sysinfo.os == :unix
  end

end