#!/usr/bin/ruby

# 
# Usage: test/60_rbox_upload_test.rb
#

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "rubygems"
require "stringio"
require "yaml"
require "rye"

tmpdir = Rye.sysinfo.tmpdir

rbox = Rye::Box.new("localhost", :info => true)
def rbox.rm(*args); __allow('rm', args); end
rbox.rm(:r, :f, "#{tmpdir}/rye-upload") # Silently delete test dir

# /tmp/rye-upload will be created if it doesn't exist
rbox.file_upload("README.rdoc", "LICENSE.txt", "#{tmpdir}/rye-upload")

# A single file can be renamed
rbox.file_upload("README.rdoc", "#{tmpdir}/rye-upload/README-renamed")

# StringIO objects can be sent as files
applejack = StringIO.new
applejack.puts "Delano: What's happening Applejack?"
applejack.puts "Applejack: Just trying to get by."
rbox.file_upload(applejack, "#{tmpdir}/rye-upload/applejack")

rbox.file_upload("tst/60-file.mp3", "#{tmpdir}/rye-upload")  # demonstrates
rbox.file_upload("tst/60-file.mp3", "#{tmpdir}/rye-upload")  # progress
rbox.file_upload("tst/60-file.mp3", "#{tmpdir}/rye-upload")  # bar

puts "Content of /tmp/rye-upload"
puts rbox.ls(:l, "#{tmpdir}/rye-upload")

rbox.file_download("#{tmpdir}/rye-upload/README.rdoc", 
              "#{tmpdir}/rye-upload/README-renamed", "#{tmpdir}/rye-download")

# You can't download a StringIO object. This raises an exception:
#rbox.file_download(applejack, "#{tmpdir}/rye-download/applejack") 
# But you can download _to_ a StringIO object
applejack = StringIO.new
rbox.file_download("#{tmpdir}/rye-upload/applejack", applejack)

puts $/, "Content of /tmp/rye-download"
puts rbox.ls(:l, "#{tmpdir}/rye-download")

puts $/, "Content of applejack StringIO object"
applejack.rewind
puts applejack.read