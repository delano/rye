
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
  #       def special(*args); __allow("/your/special/command", args); end
  #     end
  #
  #     rbox = Rye::Box.new('somehost')
  #     rbox.special        # => "special on somehost"
  #
  module Cmd
    
    # NOTE: See Rye::Box for the implementation of cd
    #def cd(*args); __allow('cd', args); end
    #def rm(*args); __allow('rm', args); end
    def wc(*args); __allow('wc', args); end
    def cp(*args); __allow("cp", args); end
    def mv(*args); __allow("mv", args); end
    def ls(*args); __allow('ls', args); end
    def ps(*args); __allow('ps', args); end
    def sh(*args); __allow('sh', args); end
    def df(*args); __allow('df', args); end
    def du(*args); __allow('du', args); end
    def su(*args); __allow('su', args); end
    def ln(*args); __allow('ln', args); end
    def ab(*args); __allow('ab', args); end
    def hg(*args); __allow('hg', args); end
    def xz(*args); __allow('xz', args); end
    
    def env; __allow "env"; end
    def rye(*args); __allow "rye", args; end
    def pwd(*args); __allow "pwd", args; end
    def svn(*args); __allow('svn', args); end
    def cvs(*args); __allow('cvs', args); end
    def git(*args); __allow('git', args); end
    def sed(*args); __allow('sed', args); end
    def awk(*args); __allow('awk', args); end
    def cat(*args); __allow('cat', args); end
    def tar(*args); __allow('tar', args); end
    def try(*args); __allow('tar', args); end
    
    #def kill(*args); __allow('kill', args); end
    def rake(*args); __allow('rake', args); end
    def grep(*args); __allow('grep', args); end
    def date(*args); __allow('date', args); end
    def ruby(*args); __allow('ruby', args); end
    def rudy(*args); __allow('rudy', args); end
    def perl(*args); __allow('perl', args); end
    def bash(*args); __allow('bash', args); end
    def echo(*args); __allow('echo', args); end
    def test(*args); __allow('test', args); end
    def mkfs(*args); __allow('mkfs', args); end
    def gzip(*args); __allow('gzip', args); end
    def make(*args); __allow('make', args); end
    def wget(*args); __allow('wget', args); end
    def curl(*args); __allow('curl', args); end
    def dpkg(*args); __allow('dpkg', args); end
    def unxz(*args); __allow('unxz', args); end
    
    def mount(*args); __allow("mount", args); end
    def sleep(*args); __allow("sleep", args); end
    def mkdir(*args); __allow('mkdir', args); end
    def touch(*args); __allow('touch', args); end
    def uname(*args); __allow('uname', args); end
    def chmod(*args); __allow('chmod', args); end
    def chown(*args); __allow('chown', args); end
    def unzip(*args); __allow('unzip', args); end
    def bzip2(*args); __allow('bzip2', args); end
    def which(*args); __allow('which', args); end
    def siege(*args); __allow("siege", args); end
    def stella(*args); __allow("stella", args); end
    
    def umount(*args); __allow("umount", args); end
    def stella(*args); __allow('stella', args); end
    def uptime(*args); __allow("uptime", args); end
    def python(*args); __allow('python', args); end
    def gunzip(*args); __allow('gunzip', args); end
    def useradd(*args); __allow('useradd', args); end
    def bunzip2(*args); __allow('bunzip2', args); end
    def getconf(*args); __allow('getconf', args); end
    def history(*args); __allow('history', args); end
    def rudy_s3(*args); __allow('rudy-s3', args); end
    def aptitude(*args); __allow('aptitude', args); end
    def printenv(*args); __allow('printenv', args); end
    def hostname(*args); __allow('hostname', args); end
    def ldconfig(*args); __allow('ldconfig', args); end
    def rudy_ec2(*args); __allow('rudy-ec2', args); end
    def rudy_sdb(*args); __allow('rudy-sdb', args); end
    def configure(*args); __allow('./configure', args); end
    
    #--
    # WINDOWS
    #++
    def dir(*args); __allow('cmd', args); end
        
    # Transfer files to a machine via Net::SCP. 
    # * +paths+ is an Array of files to upload. The last element is the 
    # directory to upload to. If uploading a single file, the last element
    # can be a file path. The list of files can also include StringIO objects.
    # The target directory will be created if it does not exist, but only 
    # when multiple files are being transferred. 
    # This method will fail early if there are obvious problems with the input
    # parameters. An exception is raised and no files are transferred. 
    # Always return nil.
    #
    # NOTE: Changes to current working directory with +cd+ or +[]+ are ignored.
    def file_upload(*paths); net_scp_transfer!(:upload, false, *paths); end

    # Transfer files from a machine via Net::SCP. 
    # * +paths+ is an Array of files to download. The last element must be the 
    # local directory to download to. If downloading a single file the last 
    # element can be a file path. The target can also be a StringIO object.
    # The target directory will be created if it does not exist, but only 
    # when multiple files are being transferred. 
    # This method will fail early if there are obvious problems with the input
    # parameters. An exception is raised and no files are transferred.
    # Return nil or a StringIO object, if specified as the target.
    #
    # NOTE: Changes to current working directory with +cd+ or +[]+ are ignored.
    def file_download(*paths); net_scp_transfer!(:download, false, *paths); end
    
    # Same as file_upload except directories are processed recursively. If
    # any supplied paths are directories you need to use this method and not 
    # file_upload. 
    def dir_upload(*paths); net_scp_transfer!(:upload, true, *paths); end
    alias_method :directory_upload, :dir_upload
    
    # Same as file_download except directories are processed recursively. If
    # any supplied paths are directories you need to use this method and not 
    # file_download. 
    def dir_download(*paths); net_scp_transfer!(:download, true, *paths); end
    alias_method :directory_download, :dir_download
    
    # Shorthand for +file_download('remote/path').string+
    #
    # Returns a String containing the content of all remote *paths*. 
    def string_download(*paths)
      net_scp_transfer!(:download, *paths).string
    end
    alias_method :str_download, :string_download
    
    # Shorthand for +file_upload(StringIO.new('file content'), 'remote/path')+
    #
    # Uploads the content of the String +str+ to +remote_path+. Returns nil
    def string_upload(str, remote_path)
      net_scp_transfer!(:upload, StringIO.new(str), remote_path)
    end
    alias_method :str_upload, :string_upload
    
    # Shorthand for +file_append('remote/path', StringIO.new('file content'))+
    #
    # Appends the content of the String +str+ to +remote_path+. Returns nil
    def string_append(filepath, newcontent, backup=false)
      file_append(remote_path, StringIO.new(str), backup)
    end
    alias_method :str_upload, :string_upload
        
    # Append +newcontent+ to remote +filepath+. If the file doesn't exist
    # it will be created. If +backup+ is specified, +filepath+ will be 
    # copied to +filepath-previous+ before appending. 
    #
    # NOTE: Not recommended for large files. It downloads the contents.
    def file_append(filepath, newcontent, backup=false)
      content = StringIO.new
      
      if self.file_exists?(filepath)
        self.cp filepath, "#{filepath}-previous" if backup
        content = self.file_download filepath
      end
      
      if newcontent.is_a?(StringIO)
        newcontent.rewind
        content.puts newcontent.read
      else
        content.puts newcontent
      end
      
      self.file_upload content, filepath
    end
    
    # Write +newcontent+ to remote +filepath+. If the file exists
    # it will be overwritten. If +backup+ is specified, +filepath+
    # will be copied to +filepath-previous+ before appending.
    def file_write(filepath, newcontent, backup=false)
      if self.file_exists?(filepath)
        self.cp filepath, "#{filepath}-previous" if backup
      end
      
      content = StringIO.new
      content.puts newcontent
      self.file_upload content, filepath
    end
    
    
    def template_write(filepath, template)
      template_upload template, filepath
    end
    
    # Parse a template and upload that as a file to remote_path.
    def template_upload(*paths)
      remote_path = paths.pop
      templates = []
      paths.collect! do |path|      
        if StringIO === path
          path.rewind
          template = Rye::Tpl.new(path.read, "inline-template")
        elsif String === path
          raise "No such file: #{Dir.pwd}/#{path}" unless File.exists?(path)
          template = Rye::Tpl.new(File.read(path), File.basename(path))
        end
        template.result!(binding)
        templates << template
        template.path
      end
      paths << remote_path
      ret = self.file_upload *paths
      templates.each { |template| 
        tmp_path = File.join(remote_path, File.basename(template.path))
        if file_exists?(tmp_path)
          mv tmp_path, File.join(remote_path, template.basename)
        end
        template.delete 
      }
      ret
    end
    
    def file_modify(filepath, regexp, replace=nil)
      raise "File not found: #{filepath}" unless file_exists?(filepath)
      sed :i, :r, "s/#{regexp}/#{replace}/", filepath
    end
    
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
          __allow(path, *local_args)
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