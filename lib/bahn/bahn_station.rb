module Bahn
	class Station
		attr_accessor :lat, :lon, :distance, :name, :station_type
		
		def initialize json={}		
			self.name = json["value"].to_s.gsub("(S-Bahn)", "(S)") unless json["value"].nil?
			
			if json[:do_load]
				station = Agent.new.find_station(name) if json[:load] == :station
				station = Agent.new.find_address(name) if json[:load] == :foot
			end
			
			if station.nil?
				self.lat = json["ycoord"].insert(-7, ".") unless json["ycoord"].nil?
				self.lon = json["xcoord"].insert(-7, ".") unless json["xcoord"].nil?
			else
				self.lat = station.lat
				self.lon = station.lon
			end
		end
		
		def to_s
                  return "#{self.name}" if (self.lat.nil? || self.lon.nil?)
                  return "#{self.name} (#{self.lat},#{self.lon})"
		end
		
		def to_coordinates
			[lat, lon]
		end
		alias_method :coordinates, :to_coordinates
		
		def == other
			return false if other.nil?
			remove_parenthesis(other.name) == remove_parenthesis(name)
		end
		
		
		#############################################
		private
		#############################################
		
		# Often we have stations like "Berlin Gesundbrunnen (S)" and "Berlin Gesundbrunnen" 
		# we want these stations to be different
		def remove_parenthesis string
			x = string.dup
			while x.gsub!(/\([^()]*\)/,""); end
			x.strip
		end
	end
end
