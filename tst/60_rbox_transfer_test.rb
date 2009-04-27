#!/usr/bin/ruby

# 
# Usage: test/60_rbox_upload_test.rb
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'stringio'
require 'yaml'
require 'rye'


rbox = Rye::Box.new('localhost', :info => true)
rbox.rm(:r, :f, '/tmp/rye-upload') # Silently delete test dir

# /tmp/rye-upload will be created if it doesn't exist
rbox.upload('README.rdoc', 'LICENSE.txt', '/tmp/rye-upload')

# A single file can be renamed
rbox.upload('README.rdoc', '/tmp/rye-upload/README-renamed')

# StringIO objects can be sent as files
applejack = StringIO.new
applejack.puts "1What's happening Applejack?"
applejack.puts "2What's happening Applejack?"
rbox.upload(applejack, '/tmp/rye-upload/applejack')

#rbox.upload('tst/60-file.mp3', '/tmp/rye-upload')  # demonstrates
#rbox.upload('tst/60-file.mp3', '/tmp/rye-upload')  # progress
#rbox.upload('tst/60-file.mp3', '/tmp/rye-upload')  # bar

puts "Content of /tmp/rye-upload"
puts rbox.ls(:l, '/tmp/rye-upload')

rbox.download('/tmp/rye-upload/README.rdoc', 
              '/tmp/rye-upload/README-renamed', '/tmp/rye-download')

# You can't download a StringIO object. This raises an exception:
#rbox.download(applejack, '/tmp/rye-download/applejack') 
# But you can download _to_ a StringIO object
applejack = StringIO.new
rbox.download('/tmp/rye-upload/applejack', applejack)

puts "Content of /tmp/rye-download"
puts rbox.ls(:l, '/tmp/rye-download')
puts "Content of applejack StringIO object"
applejack.rewind
puts applejack.read