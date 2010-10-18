require 'rye'

opts = {
  :user => 'ethel',
  :info => STDOUT,
  #:debug => STDOUT,
  :keys => 'tst/pkey-withpass-rsa',
  :passphrase => 'rye1.0'
}

rbox = Rye::Box.new 'localhost', opts
puts rbox.uptime
