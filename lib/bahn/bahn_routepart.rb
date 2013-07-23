# encoding: utf-8

module Bahn
	# Route Parts show a small step of the route from A to B with one specific type of transportation
	# Example: "Am 2013-02-01 von 17:33 bis 17:47 : Heerdter Sandberg U, Düsseldorf nach Düsseldorf Hauptbahnhof via U 7"
	class RoutePart
		attr_accessor :start, :target, :type, :platform, :price, :start_time, :end_time, :start_delay, :target_delay
           
                def initialize
                  @start_delay = 0
                  @target_delay = 0
                end

		# Return a nicely formatted route
		# Raises errors if not everything is set properly
		def to_s
			"Am #{start_time.to_date} von #{start_time.to_formatted_s :time} bis #{end_time.to_date.to_s + ' ' if end_time.to_date != start_time.to_date}#{end_time.to_formatted_s :time} : #{start} nach #{target} via #{type}"
		end
		
		# Set the type, e.g. Fußweg
		def type= val
			@type = val.squeeze(" ")
		end
		
		def transport_type
			short_type = self.type.split.first.downcase
			if ["str", "u", "s", "re", "erb", "ic", "ice"].include? short_type
				return :train
			elsif ["bus", "ne"].include? short_type
				return :bus
			elsif "Fußweg" == short_type
				return :foot
			end
			
			# nothing else works
			self.type
		end
	end
end
