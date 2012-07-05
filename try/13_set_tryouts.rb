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

@para_set_test = Rye::Set.new(
  "parallel test set",
  :parallel => true
)
@para_set_test.add_boxes("localhost", "_")

## save any raised exceptions
@para_set_test.hostname.last.first.class
#=> SocketError

## save any raised exceptions alongside normal results
@para_set_test.hostname.first.first.class
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
