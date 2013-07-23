# encoding: utf-8

module Bahn
	# Route Parts show a small step of the route from A to B with one specific type of transportation
	# Example: "Am 2013-02-01 von 17:33 bis 17:47 : Heerdter Sandberg U, Düsseldorf nach Düsseldorf Hauptbahnhof via U 7"
	class RoutePart
		attr_accessor :start, :target, :type, :platform_start, :platform_target, :price, :start_time, :end_time, :start_delay, :target_delay
           
                def initialize
                  @start_delay = 0
                  @target_delay = 0
                end

		# Return a nicely formatted route
		# Raises errors if not everything is set properly
		def to_s
                  "Am %s von %s%s bis %s%s: %s (Gl. %s) nach %s (Gl. %s) via %s" % 
                    [ start_time.to_date,
                      start_time.to_formatted_s(:time),
                      (start_delay > 0 ? " (+%i)" % start_delay : ""),
                      (end_time.to_date != start_time.to_date ? end_time.to_date.to_s + ' ' : "") + end_time.to_formatted_s(:time),
                      target_delay > 0 ? " (+%i)" % target_delay : "",
                      start.name, platform_start, target.name, platform_target, type]
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

                def ==(rp)
                  self.start == rp.start &&
                    self.target == rp.target &&
                    self.type == rp.type &&
                    self.platform_start == rp.platform_start &&
                    self.platform_target == rp.platform_target && 
                    self.start_time == rp.start_time &&
                    self.end_time == rp.end_time
                end
	end
end
