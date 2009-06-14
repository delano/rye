#!/usr/bin/ruby

# THIS IS A SCRAP FILE.

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rye'

user = Rye.sysinfo.user

rbox = Rye::Box.new('localhost', :debug => STDOUT)
rset = Rye::Set.new
rset.add_boxes(rbox, 'localhost')

# Grep processes from a single machine
ps_box = rbox.ps('a').grep(/#{user}/)
puts ps_box.size
p ps_box

# Grep processes for all machines in a set
ps_set = rset.ps('a').grep(/#{user}/)
puts ps_set.size, ps_set.first.size, ps_set.last.size
y ps_set

