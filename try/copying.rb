#!/usr/bin/ruby

# THIS IS A SCRAP FILE.

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rye'
boxA = Rye::Box.new('localhost', :user => "delano")
boxB = Rye::Box.new('127.0.0.1', :user => 'delano', :safe => false, :debug => STDOUT)
set = Rye::Set.new
set.add_boxes(boxA, boxB)

#p boxA['/tmp/ssh-test'].cat.stderr

#boxB['/tmp/ssh-test'].copy_to boxA['/tmp'], boxA['/tmp']


p boxA.ls(:a)
