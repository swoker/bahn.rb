# encoding: utf-8

module Bahn
	# The whole Route from A to B.
	# This is created from the m.bahn.de detail view page and parses the given data.
	# At the end you'll have a nice step by step navigation
	# Feel free to refactor ;)
	class Route
		attr_accessor :price, :parts, :notes, :start_type, :target_type
	
		# Initialize with a Mechanize::Page and a specific type 
		# The page should be the detail view of m.bahn.de
		# Parameters:
		# 	* page => Mechanize::Page
		#		* type => :door2door or :station2station
		def initialize page, options = {}
			options = {:start_type => :address, :target_type => :address, :include_coords => true}.merge(options)
			@do_load = options[:include_coords]
			self.start_type = options[:start_type]
			self.target_type = options[:target_type]
			summary_time = page.search("//div[contains(@class, 'querysummary2')]").text.gsub("\n", " ").strip
			html_parts = page.search("//div[contains(@class, 'haupt')]")
			price = html_parts.pop.text
			html_parts.pop

			route = ""
			html_parts.each do |part|
				text = part.text.strip
				next if text.start_with?("Reiseprofil") || text.include?("Einfache Fahrt") # not important
				if text.starts_with?("Hinweis", "Aktuelle Informationen")
					self.notes = "#{self.notes}\n#{text}" if !text.include?("Start/Ziel mit äquivalentem Bahnhof ersetzt")
					next
				end
				
				route << text << "\n"
			end
      
			route = route.split("\n")			
			idx = 3
			@start = RoutePart.new
			@target = RoutePart.new
			if options[:start_type] == :address
				@start.start = Station.new({"value" => route[0], :load => :foot, :do_load => @do_load})
				@start.type = "Fußweg" # route[2]
				@start.end_time = parse_date(summary_time.split("-").first.gsub(".13", ".2013"))
				@start.start_time = @start.end_time - route[1].to_i.minutes
				@start.target = route[3]
			elsif	options[:start_type] == :station
				@start.start = Station.new({"value" => route[0], :load => :station, :do_load => @do_load})
				@start.start_time = parse_date(@date.to_s + route[1])
				@start.type = route[2]
				@start.end_time = parse_date(@date.to_s + route[3])
				@start.target = Station.new({"value" => route[4], :load => :station, :do_load => @do_load})
				idx = 4
			end
			
			@date = @start.start_time.to_date # otherwise all dates will be "today"
			create_parts idx, route
			if options[:target_type] == :station
				@target = @parts.last
			elsif options[:target_type] == :address
				@target.type = "Fußweg"
				@target.target = Station.new({"value" => route.last, :load => :foot, :do_load => @do_load})
				if summary_time.split("-").last.strip.length != 5
					# Date is included in the string
					@target.end_time = parse_date(summary_time.split("-").last.gsub(".13", ".2013"))
				else
					# no date given, use start date
					@target.end_time = parse_date("#{@start.start_time.to_date} #{summary_time.split("-").last}")
				end
				
				@target.end_time += route[route.length-3].to_i.minutes				
				@parts << @target
			end
		end
		
		# Start time of the  route
		def start_time
			@parts.first.start_time
		end
		
		# End time of the route
		def end_time
			@parts.last.end_time
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
		
		# Create all general parts.
		# Set @parts, @target and @date first!
		def create_parts start_index, route
			@parts = [@start]
			i = start_index
			done_anything = false
			while i < route.length do
				if route[i..i+4].count != 5 || route[i..i+4].include?(nil)
					break
				end
				
				done_anything = true
				part = RoutePart.new
				part.start = Station.new({"value" => route[i], :load => :station, :do_load => @do_load})
				@parts.last.target = part.start
				part.type = route[i+2].squeeze
				
				begin
					part.start_time = parse_date(@date.to_s + route[i+1])
					part.end_time = parse_date(@date.to_s + route[i+3])
					part.target = Station.new({"value" => route[i+4], :load => :station, :do_load => @do_load})
					i += 4
				rescue ArgumentError
					# occures if there is a "Fußweg" in between
					part.start_time = @parts.last.end_time
					part.end_time = part.start_time + route[i+1].to_i.minutes
					part.target = Station.new({"value" => route[i+3], :load => :foot, :do_load => @do_load})
					i += 3
				end	
				
				part.end_time += 1.day if part.end_time.hour < @start.start_time.hour
				part.start_time += 1.day if part.start_time.hour < @start.start_time.hour
				
				@target.start_time = part.end_time
				@target.start = part.target
				
				# we don't want to show Fußwege from and to the same station
				@parts << part unless part.start == part.target
			end
			
			unless done_anything
				@target.start_time = @parts.last.end_time
				@target.start = @parts.last.start 
			end
		end
    
    def parse_date to_parse
      to_parse = DateTime.parse(to_parse).to_s
      to_parse = to_parse.gsub("+00:00", "+0100").gsub("+0000", "+0100")
      DateTime.parse to_parse
    end
	end
end