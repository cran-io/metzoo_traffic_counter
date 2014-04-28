require 'thread'

class Debug
	def initialize(enable=0)
		@enable = enable
	end

	def print(string)
		if @enable
			p string
		end
	end
end



class VehicleDetector

FIRST = 0
SECOND = 1

 def initialize
		
	@d = Debug.new(1)

	@flag_first = false
	@flag_second = false	

	@adc_first = ADC.new(0)
	@adc_second= ADC.new(1)
	
	@adc_threshold_first =  @adc_first.read.to_i
	@adc_threshold_second = @adc_second.read.to_i

	@d.print(@adc_threshold_first)
	#@d.print(@adc_threshold_second)
	@SENSONRS_DIST = 1
end

def looper	

	sensor_a = [] 
	sensor_b = []
    
	delta_time = Time.now

    sem_adc = Mutex.new
	
    thread_1 = Thread.new {
      loop do
        sem_adc.synchronize do
          	if detect(FIRST)
				t = Time.now
				sensor_a << t.min*60 + t.sec + t.usec * 0.000001 
      			@d.print("Entro al primer sensor")
				p sensor_a	
          	end
        end
      end
    }

    thread_2 = Thread.new {
      loop do
			sem_adc.synchronize do
				if detect(SECOND)
            		t = Time.now
					sensor_b << t.min*60 + t.sec + t.usec * 0.000001 
					@d.print("Entro al segundo sensor")
					p sensor_b
          		end
          
				if sensor_b.count > 1
					valid , speed, length = vehicle_type(sensor_a, sensor_b)
 
            		if valid 
						yield speed, length
              			sensor_a = [] 
						sensor_b = []
              			delta_time = Time.now
       		   		end
          		end
    		end 

	end


    }
    #[thread_1, thread_2].each(&:join)
	
	loop do
		p "Detector still alive"
		sleep 10.1	
	end
end

  def vehicle_type(sensor_a, sensor_b)
    dt_a = sensor_b.first.to_f - sensor_a.first.to_f
    dt_b = sensor_a.last.to_f - sensor_b.last.to_f

    #if (dt_a - dt_b).abs < 0.5
      length = dt_a.to_f * @SENSONRS_DIST / (sensor_a.last.to_f - sensor_a.first.to_f)
      speed = @SENSONRS_DIST.to_f / dt_a
      return true, speed, length
    #end
    #return false
  end


	def detect(sensor)		
		case sensor
			when FIRST
				value_first = @adc_first.read.to_i

				if @flag_first &&  value_first < (@adc_threshold_first + 5)
					@flag_first =false
					return true

				end
				
				if value_first > (@adc_threshold_first + 6)
					@flag_first = true
					sleep 0.2
					#@d.print("Flag alto")

				else
					@flag_first = false
				end
				
				return false

			when SECOND
				value_second = @adc_second.read.to_i

				if @flag_second &&  value_second < (@adc_threshold_second + 5)
					@flag_second =false
					return true

				end
				
				if value_second > (@adc_threshold_second + 6)
					@flag_second = true
					sleep 0.2
					#@d.print("Flag alto")

				else
					@flag_second = false
				end
				
				return false
			
		end
	
	end


end
  
class ADC

  def initialize(number)
        `echo cape-bone-iio > /sys/devices/bone_capemgr.9/slots`
        @path="/sys/devices/ocp.3/helper.14/AIN" + number.to_s
  end

  def read
        @readfile = File.open(@path, "r")
        value = @readfile.read
        @readfile.close
        return value
  end
end

