#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rye'

boxA = Rye::Box.new
boxB = Rye::Box.new('localhost', :user => 'delano', :safe => false, :debug => STDOUT)
set = Rye::Set.new
set.add_boxes(boxA, boxB)

#p boxA['/tmp/ssh-test'].cat.stderr

#p boxB.ls >> boxA['/tmp']

p boxB['/etc'].ls('-l hosts')
