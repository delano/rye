#!/usr/bin/ruby

# 
# Usage: test/10_rye_test.rb
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'benchmark'
require 'rubygems'
require 'stringio'
require 'yaml'
require 'rye'


machine_key = {
  :host => 'ec2-75-101-255-188.compute-1.amazonaws.com',
  :user => "root",
  :key => '/proj/git/rudy/.rudy/key-test-app.private'
}

machine_pass = {
  :host => 'ec2-75-101-255-188.compute-1.amazonaws.com',
  :user => 'pablo',
  :pass => 'pablo9001'
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

__END__

#p rset.sleep(1)

p rbox_remote.echo('$HOME')

local_files = rbox_local['/tmp/ssh-test'].ls
remote_files = rbox_remote['/etc/ssh'].ls
diff = remote_files - local_files

puts "ETC DIFF:"
puts diff

rbox_remote = Rye::Box.new('ec2-75-101-255-188.compute-1.amazonaws.com', :user => 'root', :debug => STDOUT, :safe => false, :keys => '/proj/git/rudy/.rudy/key-test-app.private')

