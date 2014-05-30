#!/usr/bin/ruby
require 'json'
require 'time'
require 'io/wait'
require 'thread'
require 'timers'

require './lib/gprs_client'
require './lib/gps'
require './lib/vehicle_detector'

CAR_LENGTH_THRESHOLD = 1.5
TRUCK_LENGTH_THRESHOLD = 3
MAX_LENGTH = 10
MIN_LENGTH = 1

_60_SECONDS = 59

latitude = longitude = time = 0
new_coordinates = false

aux_car = aux_truck = aux_bicycle = 0
car_count = truck_count = bicycle_count = 0

aux_speed_car = aux_speed_truck = aux_speed_bicycle = 0
car_speed = truck_speed = bicycle_speed = 0


delta_time = Time.now
timers = Timers.new

Agent = "cb100391-d4d9-48d2-a11c-a11ca918c38f"

new_traffic_event = ConditionVariable.new
sem = Mutex.new


Thread.abort_on_exception = true

 
gps_thread = Thread.new do
 	gps_client = GPS.new 
 	loop do
 		gps_client.read_gps do |lat,lon,t|
 			sem.synchronize do
 			
 				latitude = lat
 				longitude = lon
 				time = t

 				time != 0 ? new_coordinates = true : new_coordinates = false
 			end
 		end
 	end
end



 	
traffic_count_thread = Thread.new do
	vd = VehicleDetector.new
	vd.looper do |speed,length, time_flag|
		p "Vehicle detected, speed: " + speed.to_s + ", length: " + length.to_s
			sem.synchronize do
				# According to length, increment the corresponding counter
				if !time_flag
 					if length > TRUCK_LENGTH_THRESHOLD && length < MAX_LENGTH
 						truck_count += 1  
 						truck_speed += speed
 					end 
 					if length > CAR_LENGTH_THRESHOLD && length < TRUCK_LENGTH_THRESHOLD
 						car_count 	+= 1  
 						car_speed += speed 
 					end
 					if length < CAR_LENGTH_THRESHOLD && length > MIN_LENGTH
 						bicycle_count += 1 
 						bicycle_speed += speed
 					end 			
				end
			end

			if Time.now - delta_time > _60_SECONDS || time_flag 
 				delta_time = Time.now
 				new_traffic_event.signal
 			end
	end
end
 
gprs_thread = Thread.new do
 	@client = GPRSClient.new
 	loop do	
 		sem.synchronize do
 			new_traffic_event.wait(sem)
 			aux_car, car_count 		= car_count, 0
 			aux_truck, truck_count 		= truck_count, 0
 			aux_bicycle, bicycle_count 	= bicycle_count, 0

 			aux_speed_car = aux_car != 0 ? car_speed/aux_car : 0
 			aux_speed_truck = aux_truck != 0 ? truck_speed/aux_truck : 0
 			aux_speed_bicycle = aux_bicycle != 0 ? bicycle_speed/aux_bicycle : 0
 			car_speed = truck_speed = bicycle_speed = 0

 		end
 		if(new_coordinates)
 			@client.post("http://api.metzoo.com/metric", [["Trafic_counter", time.to_i, [aux_car, aux_truck, aux_bicycle]]].to_json, {:"content-type"=>:"application/json",:"Agent-Key"=> Agent})	
			@client.post("http://api.metzoo.com/metric", [["Trafic_counter_location", time.to_i, [latitude, longitude]]].to_json, {:"content-type"=>:"application/json",:"Agent-Key"=> Agent})
 			@client.post("http://api.metzoo.com/metric", [["Trafic_counter_speed", time.to_i, [aux_speed_car, aux_speed_truck,aux_speed_bicycle]]].to_json, {:"content-type"=>:"application/json",:"Agent-Key"=> Agent})

 		end
 	end
end


loop do
	sleep 10
	p	"Still alive!"
	p time
end
 #[gprs_thread,traffic_count_thread,gps_thread].each{|t| t.join}

