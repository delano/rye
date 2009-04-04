
require 'rubygems' unless defined? Gem
<<<<<<< HEAD:lib/rye.rb
require 'net/ssh'
require 'thread'
require 'highline'
require 'esc'
require 'sys'
=======
require 'sysinfo'
require 'escape'
require 'thread'
require 'highline'
require 'rye'
>>>>>>> f5023f2e193e5c82d5a8d06cfb877c4fd4912055:lib/rye.rb

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
<<<<<<< HEAD:lib/rye.rb
  
  unless defined?(SYSINFO)
    VERSION = 0.2.freeze
=======
  unless defined?(SYSINFO)
    VERSION = 0.1.freeze
>>>>>>> f5023f2e193e5c82d5a8d06cfb877c4fd4912055:lib/rye.rb
    SYSINFO = SystemInfo.new.freeze
  end
  
  def Rye.sysinfo; SYSINFO; end
  def sysinfo; SYSINFO;  end
  
  class CommandNotFound < RuntimeError; end
<<<<<<< HEAD:lib/rye.rb
  class NoBoxes < RuntimeError; end
=======
>>>>>>> f5023f2e193e5c82d5a8d06cfb877c4fd4912055:lib/rye.rb
  class NoHost < RuntimeError; end
  class NotConnected < RuntimeError; end
  
  # Reload Rye dynamically. Useful with irb. 
  def reload
<<<<<<< HEAD:lib/rye.rb
    pat = File.join(File.dirname(__FILE__), 'rye')
    %w{rap cmd box set}.each {|lib| load File.join(pat, "#{lib}.rb") }
  end
  

=======
    pat = File.join(File.dirname(__FILE__), 'rye', '**', '*.rb')
    Dir.glob(pat).collect { |file| load file; file; }
  end
  
  #def run
    #@bgthread = Thread.new do
    #  loop { @mutex.synchronize { approach } }
    #end
    #@bgthread.join
  #end
>>>>>>> f5023f2e193e5c82d5a8d06cfb877c4fd4912055:lib/rye.rb
end


Rye.reload
