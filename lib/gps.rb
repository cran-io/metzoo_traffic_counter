class GPS
	def initialize port, &block
		@latitude = 0
		@longitude = 0

		@device = File.new(port,'r')

		while(!@shutdown) do		
			l = @device.gets
			
			# TODO parse the line to see if it has latitude and longitude data

			@latitude = -58.0 
			@longitude = -34.0

			yield @latitude, @longitude

		end
	end

	def stop
		@shutdown = true
	end
end