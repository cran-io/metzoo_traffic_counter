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

		@base_first = 1000
		@vals_first = []
		@in_first = false
		100.times{@vals_first.<<(1000)}
		@prev_first = 1
		@n1 = 0

		@base_second = 1000
		@vals_second = []
		@in_second = false
		100.times{@vals_second.<<(1000)}
		@prev_second = 1
		@n2 = 0

		@SENSONRS_DIST = 1

		@sensor_a = [] 
		@sensor_b = []
	    
		@delta_time = Time.now
		@sensor_delta_time = Time.now
	end


	def looper	
		loop do	
			if detect(FIRST)
				@sensor_a << Time.now.to_f
				p "Entro al primer sensor " + @sensor_a.to_s
		  	end

		  	if detect(SECOND) 
				@sensor_b << Time.now.to_f 
				p "Entro al segundo sensor" + @sensor_b.to_s
			end

			if Time.now - @delta_time > 59
		  		@delta_time = Time.now
		  		yield 0, 0, true
		  	end


			if @sensor_b.count > 1 
				valid , speed, length = vehicle_type(@sensor_a, @sensor_b)

				if valid 
					yield speed, length, false
			  		@delta_time = Time.now
		   		end
			   			
			   	@sensor_a = []
				@sensor_b = []
			end

			if Time.now - @sensor_delta_time > 1
				@sensor_delta_time = Time.now
				if (@sensor_b.count - @sensor_a.count).abs > 1 || Time.now.to_f - @sensor_a.last.to_f > 4
					@sensor_a = [] 
					@sensor_b = []
				end
			end
			sleep 0.0001
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
		ret = false	
		case sensor
			when FIRST
				value_first = @adc_first.read.to_i
				val = (value_first + @prev_first) / 2.0
				if !@in_first && (val/@base_first > 1.21)
					ret = true
					@in_first=true
					#p "r " + (value_first/@base_first).to_s

				elsif @in_first == true
					if (value_first/@base_first < 1.03)
						@in_first = 5
					end
				elsif @in_first && @in_first != true
					if (value_first/@base_first < 1.03)
						@in_first -= 1
						@in_first = false if @in_first == 0
					end
				else
					#p((value_first/@base_first).to_s) if @n1 % 100 == 0
					@n1+=1

				end

				@prev_first = value_first
				@vals_first << value_first
				@vals_first.delete_at 0
				@base_first = @vals_first.inject{ |sum, el| sum + el }.to_f / @vals_first.size

				

			when SECOND
				value_second = @adc_second.read.to_i
				val = (value_second + @prev_second) / 2.0
				if !@in_second && (val/@base_second > 1.21)
					ret = true
					@in_second=true
					#p "r " + (value_second/@base_second).to_s

				elsif @in_second == true
					if (value_second/@base_second < 1.03)
						@in_second = 5
					end
				elsif @in_second && @in_second != true
					if (value_second/@base_second < 1.03)
						@in_second -= 1
						@in_second = false if @in_second == 0
					end
				else
					#p((value_second/@base_second).to_s) if @n2 % 100 == 0
					@n2+=1

				end

				@prev_second = value_second
				@vals_second << value_second
				@vals_second.delete_at 0
				@base_second = @vals_second.inject{ |sum, el| sum + el }.to_f / @vals_second.size
				
		end

		ret
	
	end


end
  
class ADC

  def initialize(number)
    `echo cape-bone-iio > /sys/devices/bone_capemgr.9/slots`
    `rm /home/traffic/metzoo_traffic_counter/adcs`
   	`ln -s /sys/devices/ocp.3/helper.* /home/traffic/metzoo_traffic_counter/adcs`
	@path="/home/traffic/metzoo_traffic_counter/adcs/AIN" + number.to_s
  end

  def read
        @readfile = File.open(@path, "r")
        value = @readfile.read
        @readfile.close
        return value
  end
end
