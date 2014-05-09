require 'json'
require 'timeout'
require 'io/wait'

class Debug
	def initialize(enable=false)
		@enable = enable
	end

	def print(string)
		if @enable
			p string
		end
	end
end

class GPRSClient
	def initialize 
		`echo uart1 > /sys/devices/bone_capemgr.9/slots`
		@gprs_comm = UART.new(1)
		@d = Debug.new(1)

		`stty -echo -clocal -F /dev/ttyO1`
		
		#POWER and RESET pins init
		@pin_power = 71
		@pin_reset = 70
		
		File.open("/sys/class/gpio/export","w"){|a| a.write(@pin_power)}
		File.open("/sys/class/gpio/export","w"){|a| a.write(@pin_reset)}
	
		File.open("/sys/class/gpio/gpio#{@pin_reset}/direction","w"){|a| a.write("out")}
		File.open("/sys/class/gpio/gpio#{@pin_power}/direction","w"){|a| a.write("out")}

		File.open("/sys/class/gpio/gpio#{@pin_reset}/value","w"){|a| a.write(0.to_s)}
		File.open("/sys/class/gpio/gpio#{@pin_power}/value","w"){|a| a.write(0.to_s)}
		
		
		state = :init_state																			#States of the init state machine 
		fails	=	0																								#Flag to check the fails
		ready = false
		
		@apn = "igprs.claro.com.ar"
		@user_name = "clarogprs"
		@password = "clarogprs999"
		
		@port = "80"
		

		#Starts init
		while !ready
		
			if fails == 4
				reset()
				fails = 0
			end
				
				@d.print("Fails = #{fails}")
		
			case state
				when :init_state
					if power
						@d.print("POWER ok")
						state = :attach_state
					else 
						fails += 1
					end
					
				when :attach_state	
					if attach
						@d.print("attach")
						ready = true
					else
						fails +=1
					end
					
			end
		end
	end
	
	def attach	
			attach_at_commands = [	"AT+CPIN?", 
														"AT+CREG?", 
														"AT+CGATT?", 
														"AT+CIPSHUT", 
														"AT+CIPSTATUS", 
														"AT+CIPMUX=0", 
														"AT+CSTT=\"igprs.claro.com.ar\",\"clarogprs\",\"clarogprs999\"", 
														"AT+CIICR", 
														"AT+CIFSR"] 
			
			attach_at_response =  [	"OK",
														"OK",
														"OK",
														"SHUT OK",
														"IP INITIAL",
														"OK",
														"OK",
														"OK",
														".",]
														
			attach_at_commands.each_with_index do  |item, index|
				@gprs_comm.writeline(item)
				if !wait_resp(8,attach_at_response[index])
					@d.print(item)
					return false 
					
				end
			end
			
		end
	
	def reset
		
		#Set reset pin
		File.open("/sys/class/gpio/gpio#{@pin_reset}/value","w"){|a| a.write(1.to_s)}
		sleep 1.2
		File.open("/sys/class/gpio/gpio#{@pin_reset}/value","w"){|a| a.write(0.to_s)}
		sleep 2
		
		reset_at_commands = [		"AT+CIPSTATUS", 
														"AT+CIPCLOSE", 
														"AT&F", 
														"ATE0" ] 
			
	
		
			reset_at_commands.each do  |item|
				@gprs_comm.writeline(item)
				if !wait_resp(3,"OK")
					return false 
				end
			end
		
			return true
	end
	
	def power
		
		#Turn on pin power
		File.open("/sys/class/gpio/gpio#{@pin_power}/value","w"){|a| a.write(1.to_s)}
		sleep 1.2
		File.open("/sys/class/gpio/gpio#{@pin_power}/value","w"){|a| a.write(0.to_s)}
		sleep 2
		
		reset_at_commands = [		"AT&F0", 
														"ATE0", 
														"AT&F", 
														"ATE0" ] 

			reset_at_commands.each do  |item|
				@gprs_comm.writeline(item)
				if !wait_resp(3,"OK")
					return false 
				end
			end
			
			return true
	end
	
	def wait_resp(timeout, expected_string)
	
		begin 
				Timeout::timeout(timeout) do
				while !@gprs_comm.readfile.ready?
				end
				
				loop do
				
					input_string = @gprs_comm.readline
					#p "    " + input_string
					if input_string.include?(expected_string)
						return true
					end
					
				end
			end
			
		rescue Timeout::Error
			return false
		end
	
	end
		
	def empty_buff	
		wait_resp(1, "HOla") 
	end
	
	def post(url, data, headers)
		empty_buff
		
		url_split = url.split("//")
		url_split = url_split[1].split("/")
		
		headers_arr = "POST /#{url_split[1]} HTTP/1.1\nHost: #{url_split[0]}\nContent-Length: #{data.length}\nAccept: json\n"
		
		headers.each do |key, value|
			
			headers_arr += "#{key.to_s}: #{value.to_s}\n"
	
		end
		
		total_length = data.length + headers_arr.length + headers.count + 6
	
		@gprs_comm.writeline("AT+CIPSTART=\"TCP\",\"#{url_split[0]}\",\"#{@port}\"")
		if !wait_resp(10,"CONNECT OK")
					return false 
		end
		
		
		@d.print(headers_arr + "\n" + data)
		

		@gprs_comm.writeline("AT+CIPSEND=#{total_length}")
		sleep 1
		@gprs_comm.write(headers_arr + "\n" + data)
		if !wait_resp(10,"SEND OK")
					return false 
		end
		
		#PARSER

		data_response = ""
		input_string = ""
		char_count = 0

					loop do
					
						input_string = @gprs_comm.readline
						 
					
						if input_string.include?("HTTP")
							if ! input_string.include?("2")
								return false
							end

						end
						if input_string.include?("Content-Length")
							char_count = input_string.split(":").last
						end
					
						if input_string.include?("{") 
							break
						end
					
					
					end
			internal_count = 0
			data_response += input_string
			until internal_count >= (char_count.to_i - 3) 
				
				input_string = @gprs_comm.readline
				data_response += input_string
				internal_count += input_string.length
				
				
			
			end			
			data_response += "}"
			#@d.print(data_response)	


		
		sleep 2
		@gprs_comm.writeline("AT+CIPCLOSE")
		if !wait_resp(10,"CLOSE OK")
					@d.print("asdasd")
					return false 
		end
		
		return data_response
	
		
	end
end



class UART
	attr_accessor :readfile
	attr_accessor :writefile

  def initialize(number)
    path="/dev/ttyO" + number.to_s
    @readfile = File.open(path, "r")
    @writefile = File.open(path, "w")
  end
  
  def readline
      @readfile.gets
  end
	
  def write(write_string)
	@writefile.write(write_string.to_s)
  end
  
  def writeline(write_string)
      @writefile.write (write_string.to_s + "\n")
  end           
end
