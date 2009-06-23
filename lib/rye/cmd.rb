
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
    
    # NOTE: See Rye::Box for the implementation of cd
    #def cd(*args); cmd('cd', args); end
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
    def rye(*args); cmd "rye", args; end
    def pwd(*args); cmd "pwd", args; end
    def svn(*args); cmd('svn', args); end
    def cvs(*args); cmd('cvs', args); end
    def git(*args); cmd('git', args); end
    def sed(*args); cmd('sed', args); end
    def awk(*args); cmd('awk', args); end
    def cat(*args); cmd('cat', args); end
    def tar(*args); cmd('tar', args); end
    
    #def kill(*args); cmd('kill', args); end
    def sudo(*args); cmd('sudo', args); end
    def grep(*args); cmd('grep', args); end
    def date(*args); cmd('date', args); end
    def ruby(*args); cmd('ruby', args); end
    def rudy(*args); cmd('rudy', args); end
    def perl(*args); cmd('perl', args); end
    def bash(*args); cmd('bash', args); end
    def echo(*args); cmd('echo', args); end
    def test(*args); cmd('test', args); end
    def mkfs(*args); cmd('mkfs', args); end
    def gzip(*args); cmd('gzip', args); end
    def make(*args); cmd('make', args); end
    
    def mount(*args); cmd("mount", args); end
    def sleep(*args); cmd("sleep", args); end
    def mkdir(*args); cmd('mkdir', args); end
    def touch(*args); cmd('touch', args); end
    def uname(*args); cmd('uname', args); end
    def chmod(*args); cmd('chmod', args); end
    def chown(*args); cmd('chown', args); end
    def unzip(*args); cmd('unzip', args); end
    def bzip2(*args); cmd('bzip2', args); end
    def which(*args); cmd('which', args); end
    
    def umount(*args); cmd("umount", args); end
    def uptime(*args); cmd("uptime", args); end
    def python(*args); cmd('python', args); end
    def gunzip(*args); cmd('gunzip', args); end
    def useradd(*args); cmd('useradd', args); end
    def bunzip2(*args); cmd('bunzip2', args); end
    def getconf(*args); cmd('getconf', args); end
    def history(*args); cmd('history', args); end
    def rudy_s3(*args); cmd('rudy-s3', args); end
    def printenv(*args); cmd('printenv', args); end
    def hostname(*args); cmd('hostname', args); end
    def rudy_ec2(*args); cmd('rudy-ec2', args); end
    def rudy_edb(*args); cmd('rudy-sdb', args); end
    def configure(*args); cmd('./configure', args); end
    
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
    def file_upload(*files); net_scp_transfer!(:upload, *files); end

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
    def file_download(*files); net_scp_transfer!(:download, *files); end
    
    # Shorthand for +file_download('remote/path').string+
    #
    # Returns a String containing the content of all remote *files*. 
    def string_download(*files)
      net_scp_transfer!(:download, *files, StringIO.new).string
    end
    alias_method :str_download, :string_download
    
    # Shorthand for +file_upload(StringIO.new('file content'), 'remote/path')+
    #
    # Uploads the content of the String +str+ to +remote_path+. Returns nil
    def string_upload(str, remote_path)
      net_scp_transfer!(:upload, StringIO.new(str), remote_path)
    end
    alias_method :str_upload, :string_upload
      
    
    # Append +newcontent+ to remote +filepath+. If the file doesn't exist
    # it will be created. If +backup+ is specified, +filepath+ will be 
    # copied to +filepath-previous+ before appending. 
    def file_append(filepath, newcontent, backup=false)
      if self.file_exists?(filepath)
        self.cp filepath, "#{filepath}-previous" if backup
        file_content = self.file_download filepath
      end

      file_content ||= StringIO.new
      if newcontent.is_a?(StringIO)
        newcontent.rewind
        file_content.puts newcontent.read
      else
        file_content.puts newcontent
      end
      
      self.file_upload file_content, filepath
    end
    
    #--   
    #def file_modify(filepath, regexp, replace=nil, &block)
    #  raise "File not found: #{filepath}" unless self.file_exists?(filepath)
    #end
    #++
    
    # Does +path+ from the current working directory?
    def file_exists?(path)
      begin
        ret = self.quietly { ls(path) }
      rescue Rye::CommandError => ex
        ret = ex.rap
      end
      # "ls" returns a 0 exit code regardless of success in Linux
      # But on OSX exit code is 1. This is why we look at STDERR. 
      ret.stderr.empty?
    end
    
    # Does the calculated digest of +path+ match the known +expected_digest+?
    # This is useful for verifying downloaded files. 
    # +digest_type+ must be one of: :md5, :sha1, :sha2
    def file_verified?(path, expected_digest, digest_type=:md5)
      return false unless file_exists?(path)
      raise "Unknown disgest type: #{digest_type}" unless can?("digest_#{digest_type}")
      digest = self.send("digest_#{digest_type}", path).first
      info "#{digest_type} (#{path}) = #{digest}"
      digest.to_s == expected_digest.to_s
    end
    
    # * +files+ An Array of file paths 
    # Returns an Array of MD5 digests for each of the given files
    def digest_md5(*files)
      files.flatten.collect { |file| 
        File.exists?(file) ? Digest::MD5.hexdigest(File.read(file)) : nil
      }
    end
    
    # * +files+ An Array of file paths 
    # Returns an Array of SH1 digests for each of the given files
    def digest_sha1(*files)
      files.flatten.collect { |file| 
        File.exists?(file) ? Digest::SHA1.hexdigest(File.read(file)) : nil
      }
    end
    
    # * +files+ An Array of file paths 
    # Returns an Array of SH2 digests for each of the given files
    def digest_sha2(*files)
      files.flatten.collect { |file| 
        File.exists?(file) ? Digest::SHA2.hexdigest(File.read(file)) : nil
      }
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
    
    def Cmd.can?(meth)
      instance_methods.member?(meth)
    end
    
    # A helper for adding a command to Rye::Cmd. 
    # * +meth+ the method name
    # * +path+ (optional) filesystem path for the given method
    # * +hard_args+ (optional) hardcoded arguments which are prepended to the 
    #   argument list every time the method is called
    # An optional block can be provided which will be called instead
    # of calling a system command. 
    def Cmd.add_command(meth, path=nil, *hard_args, &block)
      if block
        hard_args.unshift(path) unless path.nil? # Don't lose an argument
        define_method(meth) do |*args|
          local_args = hard_args.clone
          local_args += args
          block.call(*local_args)
        end
      else
        path ||= meth.to_s
        define_method(meth) do |*args|
          local_args = hard_args.clone
          local_args += args
          cmd(path, *local_args)
        end        
      end
    end
    
    # A helper for removing a command from Rye::Cmd. 
    # * +meth+ the method name
    def Cmd.remove_command(meth)
      remove_method(meth)
    end
    
    #--
    # * Consider a lock-down mode using method_added
    # * Consider Rye.sysinfo.os == :unix
    #++
  end

end