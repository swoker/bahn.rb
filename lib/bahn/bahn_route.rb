module Bahn
	# The whole Route from A to B.
	# This is created from the m.bahn.de detail view page and parses the given data.
	# At the end you'll have a nice step by step navigation
	# Feel free to refactor ;)
	class Route
		include ActionView::Helpers::DateHelper
		attr_accessor :price, :type, :parts
	
		# Initialize with a Mechanize::Page and a specific type 
		# The page should be the detail view of m.bahn.de
		# Parameters:
		# 	* page => Mechanize::Page
		#	* type => :door2door or :station2station
		def initialize page, type
			summary_time = page.search("//div[contains(@class, 'querysummary2')]").text.gsub("\n", " ").strip
			html_parts = page.search("//div[contains(@class, 'haupt')]")
			price = html_parts.pop.text
			html_parts.pop
			@type = type

			route = ""
			html_parts.each do |part|
				text = part.text.strip
				next if text.start_with? "Reiseprofil" # not important
				route << text << "\n"
			end
			route = route.split("\n")
			create_door2door route, summary_time if @type == :door2door
			create_station2station route if @type == :station2station
		end
		
		# Start time from now in words
		def start_time_from_now
			distance_of_time_in_words DateTime.now, @parts.first.start_time
		end
		
		# End time from now in words
		def end_time_from_now
			distance_of_time_in_words DateTime.now, @parts.last.start_time
		end
		
		# Start time of the  route
		def start_time
			@parts.first.start_time
		end
		
		# End time of the route
		def end_time
			@parts.last.start_time
		end
		
		# Starting point of the route
		def start
			@parts.first.start
		end
		
		# Target point of the route
		def target
			@parts.last.target
		end
		
		private
		
		# Create the station 2 station route parts...
		def create_station2station route
			@start = RoutePart.new
			@start.start = route[0]
			@start.start_time = DateTime.parse(@date.to_s + route[1])
			@start.type = route[2]
			@start.end_time = DateTime.parse(@date.to_s + route[3])
			@start.target = route[4]
			
			@target = RoutePart.new # avoid nullpointer

			@parts = [@start]
			create_parts 0, route
			@target = @parts.last
		end
		
		# Create the door 2 door route parts
		def create_door2door route, summary_time
			@start = RoutePart.new
			@start.start = route[0]
			@start.type = "Fußweg" # route[2]
			@start.end_time = DateTime.parse(summary_time.split("-").first.gsub(".13", ".2013"))
			@start.start_time = @start.end_time - route[1].to_i.minutes
			@start.target = route[3]
						
			@target = RoutePart.new
			@target.type = "Fußweg"
			@target.target = route.last
			if summary_time.split("-").last.strip.length != 5
				# Date is included in the string
				@target.end_time = DateTime.parse(summary_time.split("-").last.gsub(".13", ".2013"))
			else
				# no date given, use start date
				@target.end_time = DateTime.parse("#{@start.start_time.to_date} #{summary_time.split("-").last}")
			end
			
			@target.end_time += route[route.length-3].to_i.minutes
			
			@date = (@start.start_time.to_date) # otherwise all dates will be "today"
			@parts = [@start]
			create_parts 3, route
			@parts << @target
		end
		
		# Create all general parts.
		# Set @parts, @target and @date first!
		def create_parts start_index, route
			i = start_index
			while i < route.length do
				if route[i..i+4].count != 5 || route[i..i+4].include?(nil)
					break
				end
				
				part = RoutePart.new
				part.start = route[i]
				@parts.last.target = part.start
				part.type = route[i+2].squeeze
				
				begin
					part.start_time = DateTime.parse(@date.to_s + route[i+1])
					part.end_time = DateTime.parse(@date.to_s + route[i+3])
					part.target = route[i+4]
					i += 4
				rescue ArgumentError
					# occures if there is a "Fußweg" in between
					part.start_time = @parts.last.end_time
					part.end_time = part.start_time + route[i+1].to_i.minutes
					part.target = route[i+3]
					i += 3
				end	
				
				part.end_time += 1.day if part.end_time.hour < @start.start_time.hour
				part.start_time += 1.day if part.start_time.hour < @start.start_time.hour
				
				@target.start_time = part.end_time
				@target.start = part.target
				
				# we don't want to show Fußwege from and to the same station
				@parts << part unless part.start == part.target
			end
		end
	end
end