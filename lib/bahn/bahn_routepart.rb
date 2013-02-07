module Bahn
	# Route Parts show a small step of the route from A to B with one specific type of transportation
	# Example: "Am 2013-02-01 von 17:33 bis 17:47 : Heerdter Sandberg U, Düsseldorf nach Düsseldorf Hauptbahnhof via U 7"
	class RoutePart
		attr_accessor :start, :target, :type, :price, :start_time, :end_time
		
		# Return a nicely formatted route
		# Raises errors if not everything is set properly
		def to_s
			"Am #{start_time.to_date} von #{start_time.hour}:#{start_time.min} bis #{end_time.to_date.to_s + ' ' if end_time.to_date != start_time.to_date}#{end_time.hour}:#{end_time.min} : #{start} nach #{target} via #{type}"
		end
		
		# Set the type, e.g. Fußweg
		def type= val
			@type = val.squeeze(" ")
		end
	end
end