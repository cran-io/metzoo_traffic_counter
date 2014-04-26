require 'json'
require 'time'
require 'io/wait'
require 'thread'
require 'timers'

require './lib/gprs_client_tcp'
require './lib/gps'
require './lib/vehicle_detector'

CAR_LENGTH_THRESHOLD = 1.5
TRUCK_LENGTH_THRESHOLD = 3

latitude = longitude = 0
new_coordinates = false
car_count = truck_count = bicycle_count = 0
# delta_time = Time.now
timers = Timers.new

Agent = "c13c24af-c253-458c-9579-fccc17424e03"

new_traffic_event = ConditionVariable.new

 sem = Mutex.new

# p 'Starting GPS thread...'
# gps_thread = Thread.new do
# 	GPSClient.new('/dev/ttyO1') do |lat,lon|
# 		sem.synchronize do
# 			latitude = lat
# 			longitude = lon
# 			new_coordinates = true
# 		end
# 	end
# end

 p 'Starting Traffic Count Algorithm...'
  traffic_count_thread = Thread.new do
 	VehicleDetector.new(0,1) do |speed,length|
 		sem.synchronize do
 			# According to length, increment the corresponding counter
 			truck_count 	+= 1 if length > TRUCK_LENGTH_THRESHOLD
 			car_count 		+= 1 if length > CAR_LENGTH_THRESHOLD && length < TRUCK_LENGTH_THRESHOLD
 			bicycle_count += 1 if length < CAR_LENGTH_THRESHOLD

 			if Time.now - delta_time > 59
 				delta_time = Time.now
 				new_traffic_event.signal
 			end
 		end
 	end
 end

 p 'Starting GPRS thread...'
 gprs_thread = Thread.new do
 	@client = GPRSClient.new
 	loop do
 		sem.synchronize {
 			new_traffic_event.wait(sem)
 			aux_car, car_count 					= car_count, 0
 			aux_truck, truck_count 			= truck_count, 0
 			aux_bicycle, bicycle_count 	= bicycle_count, 0
 		}
 		gprs.post("http://api.metzoo.com/metric", [["Trafic_counter", Time.now.to_i, [car_count, truck_count,bicycle_count]]].to_json, {:"content-type"=>:"application/json",:"Agent-Key"=> Agent})


 	end
 end

 [gprs_thread,traffic_count_thread].each{|t| t.join}


# @client = GPRSClient.new
# timers.every(10) do
	# loop do
		# aux_car, car_count 					= rand(10), 0
		# aux_truck, truck_count 			= rand(10), 0
		# aux_bicycle, bicycle_count 	= rand(10), 0
		# begin
			# a = @client.post {:content_type => :json, :accept => :json, :name=>'hola2',:some_value=>2.0,:some_other_value=>3.5}.to_json
			# sleep 1
		# end while !a
	# end
# end

loop { timers.wait }
def new_data_type(data_count, data_type)
	{
		:id => "Contador #{data_type}",
		:description => "Cantidad de #{data_type}",
		:submetrics => ["#{data_count}"],
		:y_title => data_type,
		:polling_interval => 60,
		:enabled => true,
		:read_only => false
	}
end
