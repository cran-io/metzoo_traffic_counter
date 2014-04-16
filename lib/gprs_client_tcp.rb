require "timeout"

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

class GPRSClient
	def initialize(baudrate=0)
		@gprs_comm = UART.new(1, 1)
		@d = Debug.new(1)

		@d.print("initialize")
		`stty -echo -clocal -F /dev/ttyO1`

		@reset_pin = 139
		@on_off_pin = 144

		File.open("/sys/class/gpio/export","w"){|a| a.write(@reset_pin.to_s)}
		File.open("/sys/class/gpio/export","w"){|a| a.write(@on_off_pin.to_s)}
		
		File.open("/sys/class/gpio/gpio#{@reset_pin}/direction","w"){|a| a.write("out")}
		File.open("/sys/class/gpio/gpio#{@on_off_pin}/direction","w"){|a| a.write("out")}

		File.open("/sys/class/gpio/gpio#{@reset_pin}/value","w"){|a| a.write(0.to_s)}
		File.open("/sys/class/gpio/gpio#{@on_off_pin}/value","w"){|a| a.write(0.to_s)}

		@d.print("pin settings ok")
		
		
		state = :init_state																			#States of the init state machine 
		fails	=	0																								#Flag to check the fails
		ready = false
		
		@apn = "igprs.claro.com.ar"
		@user_name = "clarogprs"
		@password = "clarogprs999"
		@url = "23.23.141.68"
		
		@ip_address = "www.google.com"
		@port = "80"
		
		@d.print("state machine start")

		#Starts init
		while !ready
		
			reset() && fails = 0 if fails == 3
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
			@d.print("attach function")
			ip_flag = false	
							
			 #Selects Single-connection mode	
			@gprs_comm.writeline("AT+CIPMUX=0")								
					if !wait_resp(1, "OK")
						return false
					end
			@d.print("Selects Single-connection mode OK")		
			
			# Waits for status IP INITIAL		
			while !ip_flag		
					@gprs_comm.writeline("AT+CIPSTATUS")								
							if wait_resp(1, "INITIAL")
								ip_flag = true 
							end
					sleep 5
			end
			ip_flag = false
			
			@d.print("Waits for status IP INITIAL OK")
			
			#Sets the APN, user name and password	
			@gprs_comm.writeline(" AT+CSTT=\"#{@apn}\",\"#{@user_name}\",\"#{@password}\"\r ")   
			if !wait_resp(10,"OK")
				return false 
			end
			
			@d.print("Sets the APN, user name and password OK")
			
				#Waits for status IP START		
				while !ip_flag		
						@gprs_comm.writeline("AT+CIPSTATUS")								
								if wait_resp(1, "START")
									ip_flag = true 
								end
						sleep 5
				end
				ip_flag = false
				
			@d.print("Waits for status IP START OK")
		
			#Brings Up Wireless Connection	
			@gprs_comm.writeline("AT+CIICR")   
			if !wait_resp(10,"OK")
				return false 
			end
			
			@d.print("Brings Up Wireless Connection	 OK")
		
			#Waits for status IP GPRSACT		
				while !ip_flag		
						@gprs_comm.writeline("AT+CIPSTATUS")								
								if wait_resp(1, "GPRSACT")
									ip_flag = true 
								end
						sleep 5
				end
				ip_flag = false
				
			@d.print("Waits for status IP GPRSACT OK")
				
			#Gets Local IP Address
			@gprs_comm.writeline("AT+CIFSR")   
			if !wait_resp(10,".")
				return false 
			end
			
			@d.print("Gets Local IP Address OK")
			
			#Waits for status IP STATUS
				while !ip_flag		
						@gprs_comm.writeline("AT+CIPSTATUS")								
								if wait_resp(1, "IP STATUS")
									ip_flag = true 
								end
						sleep 5
				end
				ip_flag = false
				
			@d.print("Waits for status IP STATUS OK")
				
			#Opens a TCP socket
			@gprs_comm.writeline("AT+CIPSTART=\"TCP\",\"#{@ip_address}\",\"#{@port}\"")   
			if !wait_resp(30,"CONNECT OK")
				return false 
			end
			
			@d.print("Opens a TCP socket OK")
			
			return true
		end
	
	def reset
		@d.print('RESET')
		File.open("/sys/class/gpio/gpio#{@reset_pin}/value","w"){|a| a.write(1.to_s)}
		sleep 1.2
		File.open("/sys/class/gpio/gpio#{@reset_pin}/value","w"){|a| a.write(0.to_s)}
		sleep 2

		@gprs_comm.writeline("AT+CIPSTATUS")
		wait_resp(5,"OK")
		empty_buff
		
		@gprs_comm.writeline("AT+CIPCLOSE")
		wait_resp(3,"OK")
		
		@gprs_comm.writeline("AT&F")
		wait_resp(3,"OK")
		empty_buff
		
		@gprs_comm.writeline("ATE0")
		isok = wait_resp(3, "OK")
		if isok
			@d.print('RESET OK')
			return true
		else
			@d.print('RESET todo mal')
			return false
		end
	end
	
	def power
		@d.print('power method start')
		File.open("/sys/class/gpio/gpio#{@on_off_pin}/value","w"){|a| a.write(1.to_s)}
		sleep 1.2
		File.open("/sys/class/gpio/gpio#{@on_off_pin}/value","w"){|a| a.write(0.to_s)}
		sleep 2
		@d.print('power pin settings ok')
	
		empty_buff
		@d.print('empty buff ok')		
		@gprs_comm.writeline("AT&F0")
		wait_resp(3,"OK")
		@d.print('power AT&F0 OK')

		empty_buff
		@gprs_comm.writeline("ATE0")
		isok =  wait_resp(3,"OK")
		if isok
			@d.print('POWER OK')
			return true
		else
			@d.print('POWER todo mal')
			return false
		end
	 
	end
	
	def wait_resp(timeout, expected_string)
	
		begin 
			Timeout::timeout(timeout.to_i) do
				while !@gprs_comm.readfile.ready?
				end
				loop do
					input_string = @gprs_comm.readline
					p "    " + input_string
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
	
	def post(data)
		empty_buff
		
		@d.print("Post start")

		length_data = data.length		
		@gprs_comm.writeline(" AT+CIPSEND=#{length_data}")   
		if !wait_resp(10,">")
			@d.print("Length send fail")
			return false 
		end
		
		@d.print("Length send ok")

		@gprs_comm.writeline("data")   
		if !wait_resp(10,"SEND OK")
			@d.print("Data send fail")
			return false 
		end

		@d.print("Data send ok")
		
		return true
		
	end
end

class UART
	attr_accessor :readfile
	attr_accessor :writefile

  def initialize(baudrate, number)
    path="/dev/ttyO" + number.to_s
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
