require 'rye'


## a Rye::Hop instance defaults to localhost
lhop = Rye::Hop.new "localhost"
lhop.host
#=> 'localhost'

## can set up arbitray port forwards from the hop, a give you the localport
lhop = Rye::Hop.new "localhost"
lhop.host
lport = lhop.fetch_port("localhost", 22)
lport.is_a?(Fixnum)
#=> true

## Rye::Box can use Rye::Hop
lhop = Rye::Hop.new 'localhost'
lbox = Rye::Box.new 'localhost', :via => lhop
lbox.host
#=> 'localhost'

## Rye::Box still returns a Rye::Rap
lhop = Rye::Hop.new 'localhost'
lbox = Rye::Box.new 'localhost', :via => lhop
lbox.uptime.class
#=> Rye::Rap

## a Rye:Set of  Rye::Box's can use a Rye::Hop
lset = Rye::Set.new 'hopset', :parallel => true
lhop = Rye::Hop.new 'localhost'
lbox0 = Rye::Box.new 'localhost', :via => lhop
lbox1 = Rye::Box.new 'localhost', :via => lhop
lbox2 = Rye::Box.new 'localhost', :via => lhop
lset.add_boxes lbox0, lbox1, lbox2
lset.host.count
#=> 3
