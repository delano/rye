require "rye"

## Don't prompt for password if "publickey" is the only :auth_method

# May need to update this in the future with a 
# different free SSH provider
hostname = "shellmix.com"

box = Rye::Box.new(
  hostname,
  :auth_methods => ["publickey"]
)

begin
  box.connect
rescue Net::SSH::AuthenticationFailed => ex
  ex.class
end
#=> Net::SSH::AuthenticationFailed

