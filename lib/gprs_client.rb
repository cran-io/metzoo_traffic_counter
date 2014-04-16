require "gpio"
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
		@url = "cranio-api-tester.herokuapp.com/somethings"
		
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
						@d.print("attach ok")
						state = :init_http_state
						fails=0
					else
						fails +=1
					end
					
				when :init_http_state
					if initHTTP
						@d.print("http ok")
						ready = true
					else
						fails += 1
					end
			end
		end
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
	
	def attach
		@d.print("attach function")
		sleep 2
		empty_buff

		@d.print("attatch ATEO")
		@gprs_comm.writeline("ATE0")									#Disable echo
		if !wait_resp(1, "OK")
			return false
		end		
		
		@d.print("attatch AT+CIFSR")
	
	  	@gprs_comm.writeline("AT+CIFSR")								#Get Local IP Address 
	  	if !wait_resp(5,"ERROR")
	  		@d.print("AT+CIFSR OK")
			@gprs_comm.writeline("AT+CIPCLOSE")					#Close TCP or UDP Connection 
			wait_resp(5,"ERROR") 
			sleep 2
			@gprs_comm.writeline("AT+CIPSERVER=0") 		#Configure Module as server. <mode> = close server
			wait_resp(5,"ERROR") 
			return true 
	 	end
		empty_buff
		@d.print("AT+CIFSR ERROR")		
		@d.print("AT+CIPSHUT")	
		@gprs_comm.writeline("AT+CIPSHUT") 						#Deactivate GPRS PDP Context
		if !wait_resp(1, "SHUT OK")
			@d.print("AT+CIPSHUT todo mal")
			return false
		end
		
		@d.print("AT+CIPSHUT ok")

		sleep 1
		@gprs_comm.writeline(" AT+CSTT=\"#{@apn}\",\"#{@user_name}\",\"#{@password}\"\r ")   
		if !wait_resp(1,"OK")
			return false 
			@d.print("AT+CSTT  todo mal")
		end
		@d.print("AT+CSTT  ok")

	
		sleep 5
		@gprs_comm.writeline("AT+CIICR")   
		if !wait_resp(10, "OK")
			return false 
		end
		
	  	sleep 1
		@gprs_comm.writeline("AT+CIFSR") 
		if !wait_resp(5, "ERROR")
			@gprs_comm.writeline("AT+CDNSCFG=\"8.8.8.8\",\"8.8.4.4\"") 
			if wait_resp(5,"OK")
				return true 
			else
				return false 
			end
		end
		
		return false 
	end
	
	def initHTTP
		sleep 1 
		empty_buff

		@gprs_comm.writeline("AT+HTTPINIT") 
		if !wait_resp(1, "OK")
				return false
		end			

		@gprs_comm.writeline("AT+HTTPPARA=\"CID\",1") 
		if !wait_resp(1, "OK")
				return false 
		end

		#@gprs_comm.writeline("AT+HTTPPARA=\"URL\",\"#{@url}\"\r") 
		#if !wait_resp(1, "OK")
		#		return false 
		#end
					
		@gprs_comm.writeline("AT+SAPBR=3,1,\"Contype\",\"GPRS\"") 	
		if !wait_resp(1, "OK")
				return false 
		end
		
		@gprs_comm.writeline("AT+SAPBR=3,1,\"APN\",\"#{@apn}\"\r") 	
		if !wait_resp(1, "OK")
				return false 
		end
		
		@gprs_comm.writeline("AT+SAPBR=1,1") 		
		if !wait_resp(1, "OK")
				return false 
		end
		
		return true 
	end
	
	def post(url, data)
		empty_buff
		 
		#headers.each do |headers|
		
		@gprs_comm.writeline("AT+HTTPPARA=\"URL\",\"#{url}\"\r") 
		if !wait_resp(1, "OK")
				return false 
		end
		
		@gprs_comm.writeline("AT+HTTPPARA=\"CONTENT\",\"application/json\"\r") 
		if !wait_resp(1, "OK")
				return false 
		end

		#@gprs_comm.writeline("AT+HTTPPARA=\"UA\",\"603d718b-11ce-4ad0-b15e-0fbfc7be998f\"\r") 
		#if !wait_resp(1, "OK")
		#		return false 
		#end

		
		length_data = data.length	
		@gprs_comm.writeline("AT+HTTPDATA=#{length_data},40000\r");
		if !wait_resp(1, "DOWNLOAD")
				return false
		end
		
		@gprs_comm.writeline(data)
		if !wait_resp(1, "OK")
				return false
		end

		@gprs_comm.writeline("AT+HTTPACTION=1")
		if !wait_resp(5, "OK")
			return false
		end

		if !wait_resp(20, "+HTTPACTION:1,200")
			return false
		end

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
