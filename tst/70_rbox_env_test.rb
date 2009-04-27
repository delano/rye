#!/usr/bin/ruby

# 
# Usage: test/70_rbox_env_test.rb
#

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "rubygems"
require "stringio"
require "yaml"
require "rye"

tmpdir = Rye.sysinfo.tmpdir

rbox = Rye::Box.new("localhost", :info => true)

puts rbox.getenv['HOME']  # slight delay while vars are fetched
puts rbox.getenv['HOME']  # returned from memory
