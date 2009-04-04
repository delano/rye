
require 'rubygems' unless defined? Gem
require 'net/ssh'
require 'thread'
require 'highline'
require 'esc'
require 'sys'

# = Rye
#
# Rye is an library for running commands locally (via shell or SSH)
# and remotely (via SSH). 
#
# Rye is inspired by the following:
#
# * http://github.com/adamwiggins/rush
# * http://github.com/jamis/capistrano/blob/master/lib/capistrano/shell.rb
# * http://www.nofluffjuststuff.com/blog/david_bock/2008/10/ruby_s_closure_cleanup_idiom_and_net_ssh.html
# * http://groups.google.com/group/ruby-talk-google/browse_thread/thread/674a6f6de15ceb49?pli=1
# * http://paste.lisp.org/display/6912
#
module Rye
  extend self
  unless defined?(SYSINFO)
    VERSION = 0.1.freeze
    SYSINFO = SystemInfo.new.freeze
  end
  
  def Rye.sysinfo; SYSINFO; end
  def sysinfo; SYSINFO;  end
  
  class CommandNotFound < RuntimeError; end
  class NoHost < RuntimeError; end
  class NotConnected < RuntimeError; end
  
  # Reload Rye dynamically. Useful with irb. 
  def reload
    pat = File.join(File.dirname(__FILE__), 'rye', '**', '*.rb')
    Dir.glob(pat).collect { |file| load file; file; }
  end
  
  #def run
    #@bgthread = Thread.new do
    #  loop { @mutex.synchronize { approach } }
    #end
    #@bgthread.join
  #end
end


Rye.reload
