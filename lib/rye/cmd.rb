
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
  #     rbox = Rye::Box.new('somehost')
  #     rbox.special        # => "special on somehost"
  #
  module Cmd
    
    #--
    # TODO: Clean this trite mess up!
    #++
    
    def cd(*args); cmd('cd', args); end
    def wc(*args); cmd('wc', args); end
    def cp(*args); cmd("cp", args); end
    def mv(*args); cmd("mv", args); end
    def ls(*args); cmd('ls', args); end
    #def rm(*args); cmd('rm', args); end
    def ps(*args); cmd('ps', args); end
    def sh(*args); cmd('sh', args); end
    def df(*args); cmd('df', args); end
    def du(*args); cmd('du', args); end
    
    def env; cmd "env"; end
    def pwd(*args); cmd "pwd", args; end
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
    def mkfs(*args); cmd('mkfs', args); end
    
    def mount(*args); cmd("mount", args); end
    def sleep(*args); cmd("sleep", args); end
    def mkdir(*args); cmd('mkdir', args); end
    def touch(*args); cmd('touch', args); end
    def uname(*args); cmd('uname', args); end
    def chmod(*args); cmd('chmod', args); end
    def chown(*args); cmd('chown', args); end
    
    def umount(*args); cmd("umount", args); end
    def uptime(*args); cmd("uptime", args); end
    def python(*args); cmd('python', args); end
    def useradd(*args); cmd('useradd', args); end
    def getconf(*args); cmd('getconf', args); end
    def history(*args); cmd('history', args); end
    def printenv(*args); cmd('printenv', args); end
    def hostname(*args); cmd('hostname', args); end
    
    # Transfer files to a machine via Net::SCP. 
    # * +files+ is an Array of files to upload. The last element is the 
    # directory to upload to. If uploading a single file, the last element
    # can be a file path. The list of files can also include StringIO objects.
    # The target directory will be created if it does not exist, but only 
    # when multiple files are being transferred. 
    # This method will fail early if there are obvious problems with the input
    # parameters. An exception is raised and no files are transferred. 
    # Always return nil.
    #
    # NOTE: Changes to current working directory with +cd+ or +[]+ are ignored.
    def upload(*files); net_scp_transfer!(:upload, *files); end

    # Transfer files from a machine via Net::SCP. 
    # * +files+ is an Array of files to download. The last element must be the 
    # local directory to download to. If downloading a single file the last 
    # element can be a file path. The target can also be a StringIO object.
    # The target directory will be created if it does not exist, but only 
    # when multiple files are being transferred. 
    # This method will fail early if there are obvious problems with the input
    # parameters. An exception is raised and no files are transferred.
    # Return nil or a StringIO object, if specified as the target.
    #
    # NOTE: Changes to current working directory with +cd+ or +[]+ are ignored.
    def download(*files); net_scp_transfer!(:download, *files); end
    
    # Does a remote path exist?
    def file_exists?(path)
      begin
        ret = self.ls(path)
      rescue Rye::CommandError => ex
        ret = ex.rap
      end
      # "ls" returns a 0 exit code regardless of success in Linux
      # But on OSX exit code is 1. This is why we look at STDERR. 
      ret.stderr.empty?
    end
    
    # Returns the hash containing the parsed output of "env" on the 
    # remote machine. If the initialize option +:getenv+ was set to 
    # false, this will return an empty hash. 
    # This is a lazy loaded method so it fetches the remote envvars
    # the first time this method is called. 
    #
    #      puts rbox.getenv['HOME']    # => "/home/gloria" (remote)
    #
    def getenv
      if @getenv && @getenv.empty? && self.can?(:env)
        env = self.env rescue []
        env.each do |nv| 
          # Parse "GLORIA_HOME=/gloria/lives/here" into a name/value
          # pair. The regexp ensures we split only at the 1st = sign
          n, v = nv.scan(/\A([\w_-]+?)=(.+)\z/).flatten
          @getenv[n] = v
        end
      end
      @getenv
    end
     
    # Returns an Array of system commands available over SSH
    def can
      Rye::Cmd.instance_methods
    end
    alias :commands :can
    alias :cmds :can
    
    def can?(meth)
      self.can.member?(RUBY_VERSION =~ /1.9/ ? meth.to_sym : meth.to_s)
    end
    alias :command? :can?
    alias :cmd? :can?
    
    
    
    #--
    # * Consider a lock-down mode using method_added
    # * Consider Rye.sysinfo.os == :unix
    #++
  end

end