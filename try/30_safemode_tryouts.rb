require 'rye'

## enabled by default
Rye::Box.new.safe?
#=> true

## can be diabled when created
r = Rye::Box.new 'localhost', :safe => false
r.safe?
#=> false

## can be disabled on the fly
r = Rye::Box.new
r.disable_safe_mode
r.safe?
#=> false

## cannot execute arbitrary commands
begin
  r = Rye::Box.new 'localhost'
  r.execute '/bin/ls'
rescue Rye::CommandNotFound
  :success
end
#=> :success
  
## cannot remove files
begin
  r = Rye::Box.new 'localhost'
  file = "/tmp/tryouts-#{rand.to_s}"
  r.touch file
  #p [:file_exists, r.file_exists?(file)]
  r.rm file
rescue Rye::CommandNotFound
  :success
end
#=> :success

## can use file globs
begin
  r = Rye::Box.new 'localhost'
  r.ls '/bin/**'
rescue Rye::Err
  :success
end
#=> :success
  
## can use a tilda
begin
  r = Rye::Box.new 'localhost'
  r.ls '~'
rescue Rye::Err
  :success
end
#=> :success

## can execute arbitrary commands
r = Rye::Box.new 'localhost', :safe => false
ret = r.execute '/bin/ls'
ret.empty?
#=> false

## can remove files
r = Rye::Box.new 'localhost', :safe => false
file = "/tmp/tryouts-#{rand.to_s}"
r.touch file
r.rm file
r.file_exists? file
#=> false

## can use file globs
r = Rye::Box.new 'localhost', :safe => false
ret = r.ls '/bin/**'
ret.empty?
#=> false

## can use a tilda
r = Rye::Box.new 'localhost', :safe => false
ret = r.ls '~'
ret.empty?
#=> false




