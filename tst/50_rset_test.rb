#!/usr/bin/ruby

# 
# Usage: test/50_rye_test.rb
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'benchmark'
require 'rubygems'
require 'stringio'
require 'yaml'
require 'rye'


machine_key = {
  :host => 'localhost',
  :user => "delano",
  :key => '/proj/git/rudy/.rudy/key-test-app.private'
}

machine_pass = {
  :host => 'localhost',
  :user => 'delano',
#  :pass => 'pablo9001'
}

machine_local = {
  :host => "localhost"
}

rbox_key = Rye::Box.new(machine_key[:host], :user => machine_key[:user], :keys => machine_key[:key])
rbox_pass = Rye::Box.new(machine_pass[:host], :user => machine_pass[:user], :password=> machine_pass[:pass])
rbox_local = Rye::Box.new(machine_local[:host], :safe => false)


rset_serial = Rye::Set.new("example", :parallel => false) #, :debug => STDOUT
rset_parallel = Rye::Set.new("example", :parallel => true)
rset_serial.add_boxes(rbox_key, rbox_local, rbox_pass)
rset_parallel.add_boxes(rbox_key, rbox_local, rbox_pass)

# The Rehersal will be slower because they'll include the connection time
Benchmark.bmbm do |x|
  x.report('rbox:       ') { puts "%10s:%s:%s" % [rbox_key.uname, rbox_local.uname, rbox_pass.uname] }
  x.report('rset-S:') { puts "%10s:%s:%s" % rset_serial.uname }
  x.report('rset-P:') { puts "%10s:%s:%s" % rset_parallel.uname }
end

# Parallel should obviously be faster here
Benchmark.bmbm do |x|
  x.report('rbox:       ') { puts "%10s:%s:%s" % [rbox_key.sleep(2), rbox_local.sleep(2), rbox_pass.sleep(2)] }
  x.report('rset-S:') { puts "%10s:%s:%s" % rset_serial.sleep(2) }
  x.report('rset-P:') { puts "%10s:%s:%s" % rset_parallel.sleep(2) }
end
