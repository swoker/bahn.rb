module Bahn
	class RoutePart
		attr_accessor :start, :target, :type, :price, :start_time, :end_time
		
		def to_s
			"Am #{start_time.to_date} von #{start_time.hour}:#{start_time.min} bis #{end_time.to_date.to_s + ' ' if end_time.to_date != start_time.to_date}#{end_time.hour}:#{end_time.min} : #{start} nach #{target} via #{type}"
		end
	end
end