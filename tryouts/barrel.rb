#!/usr/bin/ruby

# 
# Usage: tryouts/barrel.rb
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'stringio'
require 'yaml'
require 'rye'


rset = Rye::Set.new("example", :parallel => false)
rbox = Rye::Box.new('ec2-75-101-255-188.compute-1.amazonaws.com', :user => 'root')
rset.add_boxes(rbox, 'localhost', rbox , rbox , rbox , rbox , rbox , rbox , rbox , rbox , rbox, 'localhost')
rbox.add_keys('/proj/git/rudy/.rudy/key-test-app.private')

p rset.uname


