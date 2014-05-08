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
delta_time = Time.now
timers = Timers.new

Agent = "c13c24af-c253-458c-9579-fccc17424e03"

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
 					truck_count 	+= 1 if length > TRUCK_LENGTH_THRESHOLD && length < MAX_LENGTH
 					car_count 	+= 1 if length > CAR_LENGTH_THRESHOLD && length < TRUCK_LENGTH_THRESHOLD
 					bicycle_count 	+= 1 if length < CAR_LENGTH_THRESHOLD && length > MIN_LENGTH			
				end
			end
		
			if Time.now - delta_time > _60_SECONDS || time_flag 
 				delta_time = Time.now
 				new_traffic_event.signal
 			end
	end
end
 
gprs_thread = Thread.new do
 	#@client = GPRSClient.new
 	loop do	
 		sem.synchronize do
 			new_traffic_event.wait(sem)
 			aux_car, car_count 		= car_count, 0
 			aux_truck, truck_count 		= truck_count, 0
 			aux_bicycle, bicycle_count 	= bicycle_count, 0
 		end
 		p [aux_car, aux_truck, aux_bicycle] 
 		p time
 		#@client.post("http://api.metzoo.com/metric", [["Trafic_counter", time, [aux_car, aux_truck, aux_bicycle]]].to_json, {:"content-type"=>:"application/json",:"Agent-Key"=> Agent})	
 	end
end


loop do
	sleep 10
	p	"Still alive!"
end
 #[gprs_thread,traffic_count_thread,gps_thread].each{|t| t.join}


