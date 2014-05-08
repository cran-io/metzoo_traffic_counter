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

	@SENSONRS_DIST = 1
end

def looper	

	sensor_a = [] 
	sensor_b = []
    
	delta_time = Time.now
	sensor_delta_time = Time.now


    sem_adc = Mutex.new
	
    thread_1 = Thread.new {
      loop do
        sem_adc.synchronize do
          	if detect(FIRST)
				sensor_a << Time.now.to_f
      			@d.print("Entro al primer sensor")
				p sensor_a	
          	end

          	if Time.now - delta_time > 590
          		delta_time = Time.now
          		yield 0, 0, true
          	end
        end
      end
    }

    thread_2 = Thread.new {
      loop do
			sem_adc.synchronize do
				if detect(SECOND) 
					sensor_b << Time.now.to_f 
					@d.print("Entro al segundo sensor")
					p sensor_b
          		end


				if sensor_b.count > 1 
					valid , speed, length = vehicle_type(sensor_a, sensor_b)
		 
            		if valid 
						yield speed, length, false
              			delta_time = Time.now
       		   		end
   		   			
   		   			sensor_a = []
					sensor_b = []
          		end

          		if Time.now - sensor_delta_time > 5 
        			sensor_delta_time = Time.now
        			if (sensor_b.count - sensor_a.count).abs > 1 || Time.now.to_f - sensor_a.last.to_f > 4
	        			sensor_a = [] 
						sensor_b = []
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
    dt_a = sensor_b[0].to_f - sensor_a[0].to_f
    dt_b = sensor_b[1].to_f - sensor_a[1].to_f

    p "Diference sensors " + (dt_a - dt_b).abs.to_s + " " + (sensor_a[1].to_f > sensor_b[0].to_f).to_s 
   
    if (dt_a - dt_b).abs < 4 && sensor_a[1].to_f > sensor_b[0].to_f 
      length = (sensor_a[1].to_f - sensor_a[0].to_f) * @SENSONRS_DIST / dt_a.to_f  
      speed = @SENSONRS_DIST.to_f / dt_a
      return true, speed, length
    end  
    return false
  end


	def detect(sensor)		
		case sensor
			when FIRST
				value_first = @adc_first.read.to_i
				
				if !@flag_first && value_first > (@adc_threshold_first + 6)  
					@flag_first = true
					return true
				elsif @flag_first &&  value_first < (@adc_threshold_first + 5)
					@flag_first = false
				end
				
				return false

			when SECOND
				value_second = @adc_second.read.to_i

				if !@flag_second && value_second > (@adc_threshold_second + 6)  
					@flag_second = true
					return true
				elsif @flag_second &&  value_second < (@adc_threshold_second + 5)
					@flag_second = false
				end
				
				return false
		end
	
	end


end
  
class ADC

  def initialize(number)
        `echo cape-bone-iio > /sys/devices/bone_capemgr.9/slots`
        @path="/sys/devices/ocp.3/helper.13/AIN" + number.to_s
  end

  def read
        @readfile = File.open(@path, "r")
        value = @readfile.read
        @readfile.close
        return value
  end
end

