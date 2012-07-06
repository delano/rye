require "rye"

# May need to update this in the future with a
# different free SSH provider
@hostname = "shellmix.com"

## Don't prompt for password if "publickey" is the only :auth_method
box = Rye::Box.new(
  @hostname,
  :auth_methods => ["publickey"]
)

begin
  box.connect
rescue Net::SSH::AuthenticationFailed => ex
  ex.class
end
#=> Net::SSH::AuthenticationFailed

## Never prompt for password if :no_password_prompt option is true
box = Rye::Box.new(@hostname, :no_password_prompt => true)

begin
  box.connect
rescue Net::SSH::AuthenticationFailed => ex
  ex.class
end
#=> Net::SSH::AuthenticationFailed
