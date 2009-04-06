#!/usr/bin/ruby



__END__
require 'openssl'
key = OpenSSL::PKey::RSA.generate(1024)
pub = key.public_key
ca = OpenSSL::X509::Name.parse("/C=US/ST=Florida/L=Miami/O=Waitingf/OU=Poopstat/CN=waitingf.org/emailAddress=bkerley@brycekerley.net")
cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.serial = 1
cert.subject = ca
cert.issuer = ca
cert.public_key = pub
cert.not_before = Time.now
cert.not_after = Time.now + 3600
File.open("private.pem", "w") { |f| f.write key.to_pem }
File.open("cert.pem", "w") { |f| f.write cert.to_pem }

require "openssl"


pkey = OpenSSL::PKey::RSA.new(512)
cert = OpenSSL::X509::Certificate.new
cert.version = 1
cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/C=FOO")
cert.public_key = pkey.public_key
cert.not_before = Time.now
cert.not_after = Time.now+3600*24*365
cert.sign(pkey, OpenSSL::Digest::SHA1.new)
p12 = OpenSSL::PKCS12.create("passwd", "FriendlyName", pkey, cert)
#puts p12.to_der

__END__
# Tasks demonstrated:
#       Creating a public-private key pair
#       Saving individual keys to disk in PEM format
#       Reading individual keys from disk
#       Encyrpting with public key
#       Decrypting with private key
#       Checking whether a key has public | private key

require 'openssl'

# in a real rsa implementation, message would be the symmetric key
# used to encrypt the real message data
# which would be 'yourpass' in snippet http://www.bigbold.com/snippets/posts/show/576
message = "This is some cool text."
puts "\nOriginal Message: #{message}\n"

puts "Using ruby-openssl to generate the public and private keys\n"

# .generate creates an object containing both keys
new_key = OpenSSL::PKey::RSA.generate( 1024 )
puts "Does the generated key object have the public key? #{new_key.public?}\n"
puts "Does the generated key object have the private key? #{new_key.private?}\n\n"

# write the new keys as PEM's
new_public = new_key.public_key
puts "New public key pem:\n#{new_public}\n"
puts "The new public key in human readable form:\n"
puts new_public.to_text + "\n"

output_public = File.new("./new_public.pem", "w")
output_public.puts new_public
output_public.close

new_private = new_key.to_pem
puts "new private key pem:\n#{new_private}\n"

output_private = File.new("./new_private.pem", "w")
output_private.puts new_private
output_private.close

puts "\nEncrypt/decrypt using previously saved pem files on disk...\n"
# we encrypt with the public key
# note: of course the public key PEM contains only the public key
puts "Reading Public Key PEM...\n"
public_key = OpenSSL::PKey::RSA.new(File.read("./new_public.pem"))
puts "Does the public pem file have the public key? #{public_key.public?}\n"
puts "Does the public pem file have the private key? #{public_key.private?}\n"
puts "\nEncrypting with public key ...\n"
cipher_text = public_key.public_encrypt( message )
puts "cipher text:\n#{cipher_text}\n"

# get the private key from pem file and decrypt
# note the private key PEM contains both keys
puts "\nReading Private Key PEM...\n"
private_key = OpenSSL::PKey::RSA.new(File.read("./new_private.pem"))
puts "Does the private pem file have the public key? #{private_key.public?}\n"
puts "Does the private pem file have the private key? #{private_key.private?}\n"
puts "\nDecrypting with private key ...\n"
clear_text = private_key.private_decrypt( cipher_text )
puts "\ndecoded text:\n#{clear_text}\n\n"

