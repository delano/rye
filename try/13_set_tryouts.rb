require "rye"

@dev_null = File.open("/dev/null", "w")

@opt_test_set = Rye::Set.new(
  "option passing test",
  :safe  => false,
  :debug => @dev_null,
  :error => @dev_null
)
@opt_test_set.add_boxes("11.22.33.44")
@opt_test_box = @opt_test_set.boxes.first

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

## Pass :safe option to boxes
#box = @opt_test_set.boxes.first
@opt_test_box.instance_variable_get(:@rye_safe)
#=> false

## Pass :debug option to boxes
@opt_test_box.instance_variable_get(:@rye_debug).path
#=> "/dev/null"

## Pass :error option to boxes
@opt_test_box.instance_variable_get(:@rye_error).path
#=> "/dev/null"


@dev_null.close
