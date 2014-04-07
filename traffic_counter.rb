require 'json'
require 'time'
require 'timer'
require 'io/wait'
require 'thread'

require './lib/gprs_client'
require './lib/gps'
require './lib/vehicle_detector'


CAR_LENGTH_THRESHOLD = 1.5
TRUCK_LENGTH_THRESHOLD = 3


latitude = 0
longitude = 0
new_coordinates = false

car_count = 0
truck_count = 0
bicycle_count = 0

new_traffic_event = ConditionVariable.new

sem = Mutex.new

p 'Starting GPS thread...'
gps_thread = Thread.new do
	GPSClient.new('/dev/ttyO1') do |lat,lon|
		sem.synchronize do
			latitude = lat
			longitude = lon
			new_coordinates = true
		end
	end
end

p 'Starting Traffic Count Algorithm...'
traffic_count_thread = Thread.new do
	VehicleDetector.new(1,2) do |speed,length|
		sem.synchronize do
			# According to length, increment the corresponding counter

			new_traffic_event.signal
		end
	end
end

p 'Starting GPRS thread...'
gprs_thread = Thread.new do
	@client = GPRSClient.new
	loop do
		sem.synchronize {
			new_traffic_event.wait(sem)
		}
		if new_ev
			@client.post @url,{},{}
		end

	end
end


[gprs_thread,gps_thread,traffic_count_thread].each{|t| t.join}