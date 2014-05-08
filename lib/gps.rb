# encoding: utf-8

class GPS
	attr_reader :latitude
	attr_reader :longitude
	attr_reader :time
	


	def initialize
		@gps_comm = UARTGPS.new
		@gps_comm.writeline("$PMTK314,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*29\r")
		@latitude = @longitude = @time = 0

		
	end

	
	def read_gps	
		
		data = @gps_comm.readline
		#p data
		
		if data != nil && data.include?("$GPRMC")
			@latitude = @longitude = @time = 0

			data = data.force_encoding("iso-8859-1").split(",")
			
			if(data[2] == "A" && data[12].split("*").first != "N")
				
				

				latitude_aux = data[3].slice!(0..1)
				@latitude = latitude_aux.to_i  + data[3].to_f / 60 
				data[4] == "N" ? @latitude : @latitude *= -1
				@latitude = @latitude.round(5)

				longitude_aux = data[5].slice!(0..2)
				@longitude = longitude_aux.to_i + data[5].to_f / 60
				data[6] == "E" ? @longitude : @longitude *= -1
				@longitude = @longitude.round(5)

				time_aux = data[1].slice!(0..1).to_i  #UTC to UTC-3
				time_aux.between?(0,2) ? time_hour = 21 + time_aux : time_hour = time_aux - 3
				time_min = data[1].slice!(0..1).to_i
				time_sec = data[1].to_i

				time_ddmmyy = data[9].scan(/../)


				@time = Time.new(2000 + time_ddmmyy[2].to_i, time_ddmmyy[1], time_ddmmyy[0], time_hour, time_min, time_sec, "-03:00" )
			end
		end
		
		yield @latitude, @longitude, @time
		
	end
	
end




class UARTGPS
	attr_accessor :readfile
	attr_accessor :writefile

  def initialize
    `stty ignbrk -brkint -icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke -F /dev/ttyUSB0`
    path="/dev/ttyUSB0"
    @readfile = File.open(path, "r")
    @writefile = File.open(path, "w")
  end
  
  def readline
      @readfile.gets
  end

  def writeline(write_string)
      @writefile.write (write_string.to_s + "\n")
  end           
end
