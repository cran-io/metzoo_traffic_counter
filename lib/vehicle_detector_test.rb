require './vehicle_detector'

Thread.abort_on_exception = true
v = VehicleDetector.new

v.looper do
	p "Yeah!"
end