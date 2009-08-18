#!/usr/bin/ruby

# 
# Usage: test/65_rbox_file_append_test.rb
#

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "rubygems"
require "stringio"
require "yaml"
require "rye"

tmpdir = Rye.sysinfo.tmpdir

rbox = Rye::Box.new("localhost", :info => false)
def rbox.rm(*args); __allow('rm', args); end
rbox.rm(:r, :f, "#{tmpdir}/rye-upload") # Silently delete test dir
rbox.mkdir("#{tmpdir}/rye-upload")

# Create a file with one line so we have something to append to.
initfile = StringIO.new
initfile.puts "Initial file content (before append)"
rbox.file_upload(initfile, "#{tmpdir}/rye-upload/initfile")

# Append a single line to the file
rbox.file_append("#{tmpdir}/rye-upload/initfile", "APPENDED: a single line")

puts $/, "SHOULD BE 2 lines"
puts rbox.cat("#{tmpdir}/rye-upload/initfile")

puts $/, "THE LAST APPEND DID NOT REQUEST A BACKUP. SUCCESS? (should be false):"
puts rbox.file_exists?("#{tmpdir}/rye-upload/initfile-previous")


# Append multiple lines from an Array
rbox.file_append("#{tmpdir}/rye-upload/initfile", ['line3', 'line4'])

puts $/, "SHOULD BE 4 lines"
puts rbox.cat("#{tmpdir}/rye-upload/initfile")

junk = StringIO.new
junk.puts('line5')
junk.puts('line6')
junk.puts('line7')
rbox.file_append("#{tmpdir}/rye-upload/initfile", junk, :backup)

puts $/, "SHOULD BE 7 lines"
puts rbox.cat("#{tmpdir}/rye-upload/initfile")

puts $/, "THE LAST APPEND REQUESTED A BACKUP. SUCCESS? (should be true):"
puts rbox.file_exists?("#{tmpdir}/rye-upload/initfile-previous")

