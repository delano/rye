require "rye"

@hostname = "onetimesecret.com"

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
box = Rye::Box.new(@hostname, :password_prompt => false)

begin
  box.connect
rescue Net::SSH::AuthenticationFailed => ex
  ex.class
end
#=> Net::SSH::AuthenticationFailed
