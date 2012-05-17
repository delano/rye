require "rye"

## Don't prompt for password if "publickey" is the only :auth_method

box = Rye::Box.new(
  "localhost",
  :auth_methods => ["publickey"]
)
box.remove_keys(*box.keys)
box.add_keys("tst/10-key1")
puts box.keys

e = nil
begin
  box.connect
rescue Net::SSH::AuthenticationFailed => ex
  e = ex
end
puts e.class
#=> Net::SSH::AuthenticationFailed

