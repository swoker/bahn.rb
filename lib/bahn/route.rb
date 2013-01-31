module Bahn
	class Route
		include ActionView::Helpers::DateHelper
		attr_accessor :price, :type, :parts
	
		def initialize page
			summary_time = page.search("//div[contains(@class, 'querysummary2')]").text.gsub("\n", " ").strip
			html_parts = page.search("//div[contains(@class, 'haupt')]")
			price = html_parts.pop.text
			type = html_parts.pop.text

			route = ""
			html_parts.each do |part|
				text = part.text.strip
				next if text.start_with? "Reiseprofil" # not important
				route << text << "\n"
			end
			
			create_parts route, summary_time
		end
		
		def start_time_from_now
			distance_of_time_in_words DateTime.now, @parts.first.start_time
		end
		
		def end_time_from_now
			distance_of_time_in_words DateTime.now, @parts.last.start_time
		end
		
		def start_time
			@parts.first.start_time
		end
		
		def end_time
			@parts.last.start_time
		end
		
		def start
			@parts.first.start
		end
		
		def target
			@parts.last.target
		end
		
		private
		
		def create_parts route,summary_time
			route = route.split("\n")			
			start = RoutePart.new
			start.start = route[0]
			start.type = "Fußweg" # route[2]
			start.end_time = DateTime.parse(summary_time.split("-").first.gsub(".13", ".2013"))
			start.start_time = start.end_time - route[1].to_i.minutes
			start.target = route[3]
						
			target = RoutePart.new
			target.type = "Fußweg"
			target.target = route.last
			if summary_time.split("-").last.strip.length != 5
				# Date is included in the string
				target.end_time = DateTime.parse(summary_time.split("-").last.gsub(".13", ".2013"))
			else
				# no date given, use start date
				target.end_time = DateTime.parse("#{start.start_time.to_date} #{summary_time.split("-").last}")
			end
			
			target.end_time += route[route.length-3].to_i.minutes
			# otherwise all dates will be "today"
			date = (start.start_time.to_date)
			@parts = [start]
			i = 3
			while i < route.length-4 do
				if route[i..i+4].count != 5 || route[i..i+4].include?(nil)
					break
				end
				
				part = RoutePart.new
				part.start = route[i]
				@parts.last.target = part.start
				part.type = route[i+2].squeeze
				
				begin
					part.start_time = DateTime.parse(date.to_s + route[i+1])
					part.end_time = DateTime.parse(date.to_s + route[i+3])
					part.target = route[i+4]
					i += 4
				rescue ArgumentError
					# occures if there is a "Fußweg" in between
					part.start_time = @parts.last.end_time
					part.end_time = part.start_time + route[i+1].to_i.minutes
					part.target = route[i+3]
					i += 3
				end	
				
				part.end_time += 1.day if part.end_time.hour < start.start_time.hour
				part.start_time += 1.day if part.start_time.hour < start.start_time.hour
				
				target.start_time = part.end_time
				target.start = part.target
				
				# we don't want to show Fußwege from and to the same station
				@parts << part	unless part.start == part.target
			end
			
			@parts << target
		end
	end
end