# vim: set sw=2 ts=2 :

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
  #     module Rye::Cmd
  #       def special(*args); run_command("/your/special/command", args); end
  #     end
  #
  #     rbox = Rye::Box.new('somehost')
  #     rbox.special        # => "special on somehost"
  #
  module Cmd
    
    def __shell(cmd, *args, &blk)
      self.rye_shell = true
      rap = run_command cmd, *args, &blk
      self.rye_shell = false
      rap
    end
    private :__shell
    
    # When called without a block this will open an 
    # interactive shell session. 
    def bash(*args, &blk)
      setenv('PS1', "(rye) \\h:\\w \\u\\$\ ")
      __shell 'bash', *args, &blk
    end
    
    # When called without a block this will open an 
    # interactive shell session.
    def irb(*args, &blk)
        __shell 'irb', *args, &blk
    end
    
    # When called without a block this will open an 
    # interactive shell session.
    def sh(*args, &blk)
      setenv('PS1', "(rye) $\ ")
      __shell 'sh', *args, &blk
    end
    
    # NOTE: See Rye::Box for the implementation of cd
    #def cd(*args) run_command('cd', args) end
    #def rm(*args) run_command('rm', args) end
    def wc(*args) run_command('wc', args) end
    def cp(*args) run_command("cp", args) end
    def mv(*args) run_command("mv", args) end
    def ls(*args) run_command('ls', args) end
    def ps(*args) run_command('ps', args) end
    def df(*args) run_command('df', args) end
    def du(*args) run_command('du', args) end
    def su(*args) run_command('su', args) end
    def ln(*args) run_command('ln', args) end
    def ab(*args) run_command('ab', args) end
    def hg(*args) run_command('hg', args) end
    def xz(*args) run_command('xz', args) end
    
    def env()      run_command('env')       end
    def rye(*args) run_command('rye', args) end
    def pwd(*args) run_command('pwd', args) end
    def svn(*args) run_command('svn', args) end
    def cvs(*args) run_command('cvs', args) end
    def git(*args) run_command('git', args) end
    def sed(*args) run_command('sed', args) end
    def awk(*args) run_command('awk', args) end
    def cat(*args) run_command('cat', args) end
    def tar(*args) run_command('tar', args) end
    def try(*args) run_command('tar', args) end
    
    #def kill(*args) run_command('kill', args) end
    def rake(*args) run_command('rake', args) end
    def grep(*args) run_command('grep', args) end
    def date(*args) run_command('date', args) end
    def rudy(*args) run_command('rudy', args) end
    def perl(*args) run_command('perl', args) end
    def ruby(*args) run_command('ruby', args) end
    def echo(*args) run_command('echo', args) end
    def test(*args) run_command('test', args) end
    def mkfs(*args) run_command('mkfs', args) end
    def gzip(*args) run_command('gzip', args) end
    def make(*args) run_command('make', args) end
    def wget(*args) run_command('wget', args) end
    def curl(*args) run_command('curl', args) end
    def dpkg(*args) run_command('dpkg', args) end
    def tail(*args) run_command('tail', args) end
    def unxz(*args) run_command('unxz', args) end
    
    def mount(*args) run_command("mount", args) end
    def sleep(*args) run_command("sleep", args) end
    def mkdir(*args) run_command('mkdir', args) end
    def touch(*args) run_command('touch', args) end
    def uname(*args) run_command('uname', args) end
    def chmod(*args) run_command('chmod', args) end
    def chown(*args) run_command('chown', args) end
    def unzip(*args) run_command('unzip', args) end
    def bzip2(*args) run_command('bzip2', args) end
    def which(*args) run_command('which', args) end
    def siege(*args) run_command("siege", args) end
    
    def stella(*args) run_command("stella", args) end
    def umount(*args) run_command("umount", args) end
    def stella(*args) run_command('stella', args) end
    def uptime(*args) run_command("uptime", args) end
    def python(*args) run_command('python', args) end
    def gunzip(*args) run_command('gunzip', args) end
    def whoami(*args) run_command('whoami', args) end

    def useradd(*args) run_command('useradd', args) end
    def bunzip2(*args) run_command('bunzip2', args) end
    def getconf(*args) run_command('getconf', args) end
    def history(*args) run_command('history', args) end
    def rudy_s3(*args) run_command('rudy-s3', args) end

    def aptitude(*args) run_command('aptitude', args) end
    def printenv(*args) run_command('printenv', args) end
    def hostname(*args) run_command('hostname', args) end
    def ldconfig(*args) run_command('ldconfig', args) end
    def rudy_ec2(*args) run_command('rudy-ec2', args) end
    def rudy_sdb(*args) run_command('rudy-sdb', args) end
      
    def configure(*args) run_command('./configure', args) end
    
    #--
    # WINDOWS
    #++
    def dir(*args); run_command('cmd', args); end
        
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
      net_scp_transfer!(:download, false, *paths).string
    end
    alias_method :str_download, :string_download
    
    # Shorthand for +file_upload(StringIO.new('file content'), 'remote/path')+
    #
    # Uploads the content of the String +str+ to +remote_path+. Returns nil
    def string_upload(str, remote_path)
      net_scp_transfer!(:upload, false, StringIO.new(str), remote_path)
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
      rescue Rye::Err => ex
        ret = ex.rap
      end
      # "ls" returns a 0 exit code regardless of success in Linux
      # But on OSX exit code is 1. This is why we look at STDERR. 
      !(ret.exit_status > 0) || ret.stderr.empty?
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
          run_command(path, *local_args)
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
