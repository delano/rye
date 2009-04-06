#!/usr/bin/ruby

TEST_HOME = File.dirname(__FILE__)
$:.unshift File.join(TEST_HOME, '..', 'lib')

require 'rye'

private_key_path = File.join(TEST_HOME, '10-key1')
rpk = Rye::Key.from_file(private_key_path)



puts "RYE::KEY PUBLIC KEY GOOD TIMES: #{private_key_path}", $/
puts "1-2 should be the same. I don't understand why they are not."
puts "3-6 should have identical key content (ignoring spaces and 'ssh-rsa')"

# PKCS#1 RSAPublicKey* (PEM header: BEGIN RSA PUBLIC KEY)
puts "[1] PEM encoded public key (via Rye::Key#public_key)"
puts rpk.public_key.to_pem
# -----BEGIN RSA PUBLIC KEY-----
# MIIBCAKCAQEAzRTl7NX++irdkHdH68/JFu9EXimuih6wgfDn0cIC15isHonssxN5
# i7SuIDfP9zLc9QJWgfUyn0nsdOp5Di8KStvidlMnNeZUSA2YwjQUH++1z4z5bbjU
# ixCBkn8Jv6uV+CxPeB3DFJKOrc1DKfkzf1oaUhEPPcfS78ZGM7fEW5wXX8zXOS0B
# nRvX9oTpQtypdm6vjcdZnW76eSudjJvk0yruV6UquEcud+RVNtJlM7uqgm2CEBhD
# 18qxQINwTG0NFALYMaNzXKrAu6MSvk9uHof/nSk4V5IwBh+2fQAyvukpgmqvL5yY
# Vm1mXGs4DwG9ukJ+PuGzh02sUKcGoc3yIwIBIw==
# -----END RSA PUBLIC KEY-----

# X.509 SubjectPublicKeyInfo** (PEM header: BEGIN PUBLIC KEY)
puts $/, "[2] PEM encoded public key (via openssl rsa -in #{private_key_path} -pubout)"
puts Rye.shell('openssl', "rsa -in #{private_key_path} -pubout")
# -----BEGIN PUBLIC KEY-----
# MIIBIDANBgkqhkiG9w0BAQEFAAOCAQ0AMIIBCAKCAQEAzRTl7NX++irdkHdH68/J
# Fu9EXimuih6wgfDn0cIC15isHonssxN5i7SuIDfP9zLc9QJWgfUyn0nsdOp5Di8K
# StvidlMnNeZUSA2YwjQUH++1z4z5bbjUixCBkn8Jv6uV+CxPeB3DFJKOrc1DKfkz
# f1oaUhEPPcfS78ZGM7fEW5wXX8zXOS0BnRvX9oTpQtypdm6vjcdZnW76eSudjJvk
# 0yruV6UquEcud+RVNtJlM7uqgm2CEBhD18qxQINwTG0NFALYMaNzXKrAu6MSvk9u
# Hof/nSk4V5IwBh+2fQAyvukpgmqvL5yYVm1mXGs4DwG9ukJ+PuGzh02sUKcGoc3y
# IwIBIw==
# -----END PUBLIC KEY-----


puts $/, "[3] Base64 encoded"
puts Base64.encode64(rpk.public_key.to_blob)
# AAAAB3NzaC1yc2EAAAABIwAAAQEAzRTl7NX++irdkHdH68/JFu9EXimuih6w
# gfDn0cIC15isHonssxN5i7SuIDfP9zLc9QJWgfUyn0nsdOp5Di8KStvidlMn
# NeZUSA2YwjQUH++1z4z5bbjUixCBkn8Jv6uV+CxPeB3DFJKOrc1DKfkzf1oa
# UhEPPcfS78ZGM7fEW5wXX8zXOS0BnRvX9oTpQtypdm6vjcdZnW76eSudjJvk
# 0yruV6UquEcud+RVNtJlM7uqgm2CEBhD18qxQINwTG0NFALYMaNzXKrAu6MS
# vk9uHof/nSk4V5IwBh+2fQAyvukpgmqvL5yYVm1mXGs4DwG9ukJ+PuGzh02s
# UKcGoc3yIw==

puts $/, "[4] Base64 encoded, SSH2 format (manual)"
puts Base64.encode64(rpk.public_key.to_blob).strip.gsub(/[\r\n]/, '')
# AAAAB3NzaC1yc2EAAAABIwAAAQEAzRTl7NX++irdkHdH68/JFu9EXimuih6wgfDn0cIC15isHonssxN5i7SuIDfP9zLc9QJWgfUyn0nsdOp5Di8KStvidlMnNeZUSA2YwjQUH++1z4z5bbjUixCBkn8Jv6uV+CxPeB3DFJKOrc1DKfkzf1oaUhEPPcfS78ZGM7fEW5wXX8zXOS0BnRvX9oTpQtypdm6vjcdZnW76eSudjJvk0yruV6UquEcud+RVNtJlM7uqgm2CEBhD18qxQINwTG0NFALYMaNzXKrAu6MSvk9uHof/nSk4V5IwBh+2fQAyvukpgmqvL5yYVm1mXGs4DwG9ukJ+PuGzh02sUKcGoc3yIw==

puts $/, "[5] Base64 encoded, SSH2 format (via Rye::Key.public_key.to_ssh2)"
puts rpk.public_key.to_ssh2
# ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAzRTl7NX++irdkHdH68/JFu9EXimuih6wgfDn0cIC15isHonssxN5i7SuIDfP9zLc9QJWgfUyn0nsdOp5Di8KStvidlMnNeZUSA2YwjQUH++1z4z5bbjUixCBkn8Jv6uV+CxPeB3DFJKOrc1DKfkzf1oaUhEPPcfS78ZGM7fEW5wXX8zXOS0BnRvX9oTpQtypdm6vjcdZnW76eSudjJvk0yruV6UquEcud+RVNtJlM7uqgm2CEBhD18qxQINwTG0NFALYMaNzXKrAu6MSvk9uHof/nSk4V5IwBh+2fQAyvukpgmqvL5yYVm1mXGs4DwG9ukJ+PuGzh02sUKcGoc3yIw==

puts $/, "[6] Base64 encoded, SSH2 format (via ssh-keygen -y -f #{private_key_path})"
puts Rye.shell('ssh-keygen', "-y -f #{private_key_path}")
# ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAzRTl7NX++irdkHdH68/JFu9EXimuih6wgfDn0cIC15isHonssxN5i7SuIDfP9zLc9QJWgfUyn0nsdOp5Di8KStvidlMnNeZUSA2YwjQUH++1z4z5bbjUixCBkn8Jv6uV+CxPeB3DFJKOrc1DKfkzf1oaUhEPPcfS78ZGM7fEW5wXX8zXOS0BnRvX9oTpQtypdm6vjcdZnW76eSudjJvk0yruV6UquEcud+RVNtJlM7uqgm2CEBhD18qxQINwTG0NFALYMaNzXKrAu6MSvk9uHof/nSk4V5IwBh+2fQAyvukpgmqvL5yYVm1mXGs4DwG9ukJ+PuGzh02sUKcGoc3yIw==




__END__

* http://cryptosys.net/pki/rsakeyformats.html

Public key formats supported

    * PKCS#1 RSAPublicKey* (PEM header: BEGIN RSA PUBLIC KEY)
    * X.509 SubjectPublicKeyInfo** (PEM header: BEGIN PUBLIC KEY)
    * XML <RSAKeyValue>

Encrypted private key format supported

    * PKCS#8 EncryptedPrivateKeyInfo** (PEM header: BEGIN ENCRYPTED PRIVATE KEY)

Private key formats supported (unencrypted)

    * PKCS#1 RSAPrivateKey** (PEM header: BEGIN RSA PRIVATE KEY)
    * PKCS#8 PrivateKeyInfo* (PEM header: BEGIN PRIVATE KEY)
    * XML <RSAKeyPair> and <RSAKeyValue>


