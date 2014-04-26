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

@flag_first = false
@flag_second = false

 def initialize
		
	@d = Debug.new(1)

	@adc_first = ADC.new(0)
	@adc_second= ADC.new(1)
	
	@adc_threshold_first =  @adc_first.read.to_i
	@adc_threshold_second = @adc_second.read.to_i

	@d.print(@adc_threshold_first)
	#@d.print(@adc_threshold_second)

	

	sensor_a = sensor_b = []
    @SENSONRS_DIST = 1
    delta_time = Time.now

    sem = Mutex.new
    thread_1 = Thread.new {
      loop do
        sem.synchronize do
	
	sleep 0.1
          if detect(FIRST)
            sensor_a << Time.now
		@d.print("Entro al primer sensor")	
          end
        end
      end
    }
    thread_2 = Thread.new {
      loop do
        sem.synchronize do
	sleep 0.1
	#@d.print(@adc_second.read.to_i)

          if detect(SECOND)
            sensor_b << Time.now
		@d.print("Entro al segundo sensor")
          end

          if sensor_b.count > 1
		valid , speed, length = vehicle_type(sensor_a, sensor_b) 
		yield speed, length
            if valid || Time.now - delta_time > 5
              sensor_a = sensor_b = []
              delta_time = Time.now
            end
          end
        end
      end
    }
    [thread_1, thread_2].each(&:join)
  end

  def vehicle_type(sensor_a, sensor_b)
    dt_a = sensor_b.first - sensor_a.first
    dt_b = sensor_a.last - sensor_b.last
    if (dt_a - dt_b).abs < 0.5
      length = (sensor_a.last - sensor_a.first) * @SENSONRS_DIST / dt_a
      speed = @SENSONRS_DIST / dt_a
      return true, speed, length
    end
    false
  end


	def detect(sensor)
		
		value_first = @adc_first.read.to_i
		value_second = @adc_second.read.to_i
	
		case sensor
			when FIRST

				if @flag_first
					#@d.print(value_first)
				end

				if @flag_first &&  value_first < @adc_threshold_first + 6
					@flag_first =false
					return true

				end
				
				if value_first > (@adc_threshold_first + 8)
					@flag_first = true
					sleep 0.2
					#@d.print("Flag alto")

				else
					@flag_first = false
				end
				
				return false

			when SECOND

				if @flag_second
					#@d.print(value_second)
				end

				if @flag_second &&  value_second < @adc_threshold_second + 6
					@flag_second =false
					return true

				end
				
				if value_second > (@adc_threshold_second + 8)
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
        @path="/sys/devices/ocp.3/helper.13/AIN" + number.to_s
  end

  def read
        @readfile = File.open(@path, "r")
        value = @readfile.read
        @readfile.close
        return value
  end
end

