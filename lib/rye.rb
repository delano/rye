# vim: set sw=2 ts=2 :

module Rye
  unless defined?(Rye::HOME)
    HOME = File.expand_path( File.join(File.dirname(__FILE__), '..') )
  end
end

require 'logger'
require 'thread'
require 'base64'
require 'net/ssh'
require 'net/scp'
require 'openssl'
require 'tempfile'
require 'highline'
require 'timeout'

require 'storable'
require 'sysinfo'

require 'esc'

# = Rye
#
# Safely run remote commands via SSH in Ruby.
#
# Rye is similar to Rush[http://rush.heroku.com] but everything
# happens over SSH (no HTTP daemon) and the default settings are
# less dangerous (for safety). For example, file globs and the
# "rm" command are disabled so unless otherwise specified, you
# can't do this: <tt>rbox.rm('/etc/**/*')</tt>.
#
# However, you can do this:
#
# rset = Rye::Set.new("dev-machines")
# rset.add_boxes('host1', 'host2', 'host3', 'host4')
# rset.ps('aux')
#
# * See +bin/try+ for a bunch of working examples.
# * See Rye::Box#initialize for info about disabling safe-mode.
#
#--
# The following posts were really helpful when I first wrote Rye:
# http://www.nofluffjuststuff.com/blog/david_bock/2008/10/ruby_s_closure_cleanup_idiom_and_net_ssh.html
# http://groups.google.com/group/ruby-talk-google/browse_thread/thread/674a6f6de15ceb49?pli=1
# http://paste.lisp.org/display/6912
#++
module Rye
  extend self

  module VERSION
    @path = File.join(Rye::HOME, 'VERSION')
    class << self
      attr_reader :version, :path
      def version
        @version || read_version
      end
      def read_version
        return if @version
        @version = File.read(path).strip!
      end
      def prerelease?() false end
      def to_a()     version.split('.')   end
      def to_s()     version              end
      def inspect()  version              end
    end
  end

  @@sysinfo = nil
  @@agent_env = Hash.new  # holds ssh-agent env vars
  @@mutex = Mutex.new     # for synchronizing threads

  # Accessor for an instance of SystemInfo
  def Rye.sysinfo
    @@sysinfo = SysInfo.new if @@sysinfo.nil?
    @@sysinfo
  end

  # Accessor for an instance of SystemInfo
  def sysinfo; Rye.sysinfo end

  class RyeError < RuntimeError; end
  class NoBoxes < RyeError; end
  class NoPassword < RyeError
    def message; "Password prompt did not return a value"; end
  end
  class NoHost < RyeError; end
  class NotConnected < RyeError; end
  class CommandNotFound < RyeError; end
  class NoPty < RyeError
    def message; "Could not obtain pty (i.e. an interactive ssh session)"; end
  end
  class Err < RyeError
    attr_reader :rap
    # * +rap+ a Rye::Rap object
    def initialize(rap)
      @rap = rap
    end
    def message
      "%s (cmd: %s; status: %s)" % [@rap.stderr.join($/), @rap.cmd, @rap.exit_status]
    end
    def stderr; @rap.stderr if @rap; end
    def stdout; @rap.stdout if @rap; end
    def exit_status; @rap.exit_status if @rap; end
  end

  # Reload Rye dynamically. Useful with irb.
  # NOTE: does not reload rye.rb.
  def reload
    pat = File.join(File.dirname(__FILE__), 'rye')
    %w{key rap cmd box set hop}.each {|lib| load File.join(pat, "#{lib}.rb") }
  end

  def mutex
    @@mutex
  end

  # Looks for private keys in +path+ and returns an Array of paths
  # to the files it finds. Raises an Exception if path does not exist.
  # If path is a file rather than a directory, it will check whether
  # that single file is a private key.
  def find_private_keys(path)
    raise "#{path} does not exist" unless File.exists?(path || '')
    if File.directory?(path)
      files = Dir.entries(path).collect { |file| File.join(path, file) }
    else
      files = [path]
    end

    files = files.select do |file|
      next if File.directory?(file)
      pk = nil
      begin
        tmp = Rye::Key.from_file(file)
        pk = tmp if tmp.private?
      rescue OpenSSL::PKey::PKeyError
      end
      !pk.nil?
    end
    files || []
  end

  # Add one or more private keys to the SSH Agent.
  # * +keys+ one or more file paths to private keys used for passwordless logins.
  def add_keys(*keys)
    keys = keys.flatten.compact || []
    return if keys.empty?
    Rye.shell("ssh-add", keys)
  end

  # Returns an Array of info about the currently available
  # SSH keys, as provided by the SSH Agent.
  #
  # Returns: [[bits, finger-print, file-path], ...]
  #
  def keys
    # 2048 76:cb:d7:82:90:92:ad:75:3d:68:6c:a9:21:ca:7b:7f /Users/rye/.ssh/id_rsa (RSA)
    # 2048 7b:a6:ba:55:b1:10:1d:91:9f:73:3a:aa:0c:d4:88:0e /Users/rye/.ssh/id_dsa (DSA)
    #keystr = Rye.shell("ssh-add", '-l')
    #return nil unless keystr
    #keystr.collect do |key|
    #  key.split(/\s+/)
    #end
    Dir.glob(File.join(Rye.sysinfo.home, '.ssh', 'id_*sa'))
  end

  def remote_host_keys(*hostnames)
    hostnames = hostnames.flatten.compact || []
    return if hostnames.empty?
    Rye.shell("ssh-keyscan", hostnames)
  end

  # Takes a command with arguments and returns it in a
  # single String with escaped args and some other stuff.
  #
  # * +cmd+ The shell command name or absolute path.
  # * +args+ an Array of command arguments.
  #
  # The command is searched for in the local PATH (where
  # Rye is running). An exception is raised if it's not
  # found. NOTE: Because this happens locally, you won't
  # want to use this method if the environment is quite
  # different from the remote machine it will be executed
  # on.
  #
  # The command arguments are passed through Escape.shell_command
  # (that means you can't use environment variables or asterisks).
  #
  def prepare_command(cmd, *args)
    args &&= [args].flatten.compact
    found_cmd = Rye.which(cmd)
    raise CommandNotFound.new(cmd || '[unknown]') unless found_cmd
    # Symbols to switches. :l -> -l, :help -> --help
    args.collect! do |a|
      a = "-#{a}" if a.is_a?(Symbol) && a.to_s.size == 1
      a = "--#{a}" if a.is_a?(Symbol)
      a
    end
    Rye.escape(@safe, found_cmd, *args)
  end

  # An all ruby implementation of unix "which" command.
  #
  # * +executable+ the name of the executable
  #
  # Returns the absolute path if found in PATH otherwise nil.
  def which(executable)
    return unless executable.is_a?(String)
    return executable if Rye.sysinfo.os == :windows
    #return executable if File.exists?(executable) # SHOULD WORK, MUST TEST
    shortname = File.basename(executable)
    dir = Rye.sysinfo.paths.select do |path|    # dir contains all of the
      next unless File.exists? path             # occurrences of shortname
      Dir.new(path).entries.member?(shortname)  # found in the paths.
    end
    File.join(dir.first, shortname) unless dir.empty? # Return just the first
  end

  # Execute a local system command (via the shell, not SSH)
  #
  # * +cmd+ the executable path (relative or absolute)
  # * +args+ Array of arguments to be sent to the command. Each element
  # is one argument:. i.e. <tt>['-l', 'some/path']</tt>
  #
  # NOTE: shell is a bit paranoid so it escapes every argument. This means
  # you can only use literal values. That means no asterisks too.
  #
  # Returns a Rye::Rap object.
  #
  def shell(cmd, *args)
    args = args.flatten.compact
    cmd = cmd.to_s if cmd.is_a?(Symbol)
    # TODO: allow stdin to be sent to the cmd
    tf = Tempfile.new(cmd)
    cmd = Rye.prepare_command(cmd, args)
    cmd << " 2>#{tf.path}" # Redirect STDERR to file. Works in DOS too.
    # Deal with STDOUT
    handle = IO.popen(cmd, "r")
    stdout = handle.read.chomp
    handle.close
    # Then STDERR
    stderr = File.exists?(tf.path) ? File.read(tf.path) : ''
    tf.delete
    # Create the response object
    rap = Rye::Rap.new(self)
    rap.add_stdout(stdout || '')
    rap.add_stderr(stderr || '')
    rap.add_exit_status($?)
    rap
  end

  # Creates a string from +cmd+ and +args+. If +safe+ is true
  # it will send them through Escape.shell_command otherwise
  # it will return them joined by a space character.
  def escape(safe, cmd, *args)
    args = args.flatten.compact || []
    safe ? Escape.shell_command(cmd, *args).to_s : [cmd, args].flatten.compact.join(' ')
  end

  def sshagent_info
    @@agent_env
  end

  # Returns +str+ with the leading indentation removed.
  # Stolen from http://github.com/mynyml/unindent/ because it was better.
  def without_indent(str)
    indent = str.split($/).each {|line| !line.strip.empty? }.map {|line| line.index(/[^\s]/) }.compact.min
    str.gsub(/^[[:blank:]]{#{indent}}/, '')
  end

  #
  # Generates a string of random alphanumeric characters.
  # * +len+ is the length, an Integer. Default: 8
  # * +safe+ in safe-mode, ambiguous characters are removed (default: true):
  #       i l o 1 0
  def strand( len=8, safe=true )
     chars = ("a".."z").to_a + ("0".."9").to_a
     chars.delete_if { |v| %w(i l o 1 0).member?(v) } if safe
     str = ""
     1.upto(len) { |i| str << chars[rand(chars.size-1)] }
     str
  end

  class Tpl
    attr_reader :src, :result, :basename
    def initialize(src, basename='rye-template')
      @basename = basename
      src = src.to_s
      @src, @template = src, ERB.new(src)
    end
    def path
      if @tf.nil?
        @tf = Tempfile.new basename
        @tf.write @result
        @tf.close
      end
      @tf.path
    end
    def delete
      File.delete(@tf.path) if File.exists?(@tf.path)
    end
    def result!(binding)
      @result = result(binding)
    end
    def result(binding)
      @template.result(binding)
    end
    def to_s() src end
  end

  private

  Rye.reload

end




