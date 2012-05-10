require "rye"

## save any raised exceptions
set = Rye::Set.new("set test", :parallel => true)
set.add_boxes("localhost", "_")
set.hostname.last.first.class
#=> SocketError

## save any raised exceptions alongside normal results
set = Rye::Set.new("set test", :parallel => true)
set.add_boxes("localhost", "_")
set.hostname.first.first.class
#=> String
