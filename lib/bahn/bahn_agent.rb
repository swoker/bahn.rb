module Bahn
	# Agent class that searches stations, street addresses and public transportation routes for germany
	# Example:
	# 	agent = Agent.new
	# 	routes = agent.get_routes "Düsseldorf Heerdter Sandberg 25", "Düsseldorf Am Dreieck 1"
	#	routes.each {|route| route.parts.each {|part| puts part } }
	#	
	# 	You can go even use far distances...
	#	routes = agent.get_routes "Heerdter Sandberg 35 Düsseldorf, Düsseldorf", "Berlin Hauptstraße 10"
	# 	routes.each {|route| route.parts.each {|part| puts part } }
	#		=> Am 2013-02-01 von 17:32 bis 17:33 : Düsseldorf - Oberkassel, Heerdter Sandberg 60 nach Heerdter Sandberg U, Düsseldorf via Fußweg
	#		=> Am 2013-02-01 von 17:33 bis 17:47 : Heerdter Sandberg U, Düsseldorf nach Düsseldorf Hauptbahnhof via U 7
	#		=> Am 2013-02-01 von 17:47 bis 17:53 : Düsseldorf Hauptbahnhof nach Düsseldorf Hbf via Fußweg
	#		=> Am 2013-02-01 von 17:53 bis 22:22 : Düsseldorf Hbf nach Berlin Hbf via ICE 945
	#		=> Am 2013-02-01 von 22:34 bis 22:40 : Berlin Hbf nach Berlin Alexanderplatz via RE 37386
	#		=> Am 2013-02-01 von 22:40 bis 22:46 : Berlin Alexanderplatz nach Alexanderplatz (U), Berlin via Fußweg
	#		=> Am 2013-02-01 von 22:46 bis 23:07 : Alexanderplatz (U), Berlin nach Oberseestr., Berlin via STR M5
	#		=> Am 2013-02-01 von 23:07 bis 23:15 : Oberseestr., Berlin nach Berlin - Alt-Hohenschönhausen, Hauptstraße 10 via Fußweg
	class Agent	
		@@options = {
			:url_route => 'http://mobile.bahn.de/bin/mobil/query.exe/dox?country=DEU&rt=1&use_realtime_filter=1&searchMode=ADVANCED',
			:uri_adresses => 'http://reiseauskunft.bahn.de/bin/ajax-getstop.exe/en?REQ0JourneyStopsS0A=2&REQ0JourneyStopsS0G=',
			:uri_stations => 'http://reiseauskunft.bahn.de/bin/ajax-getstop.exe/en?REQ0JourneyStopsS0A=1&REQ0JourneyStopsS0G='			
		}
	
		# Set the used user agent
		def self.user_agent=val
			@@user_agent = val
		end
		
		TYPES = 
			{
				:station => 1,
				:address => 2
			}.freeze
		
		# Initialize a new Agent
		# options:
		#  :user_agent => Set the user agent. Default: "bahn.rb"
		def initialize
			@agent = Mechanize.new
			@agent.user_agent = @@user_agent ||= "bahn.rb"
		end
		
		# Get the next few routes with public transportation from A to B.
		#
		# Options:
		# 	* :time => start time for the connection
		#   * :include_coords => Include coordiantes for the station. This takes a while especially for longer routes! default: true
		# Returns:
		# 	Array of Bahn::Route(s)
		# Raises:
		# 	"no_route" if no route could be found
		def get_routes from, to, options = {}
			options[:start_type] = check_point_type(from) || options[:start_type]
			options[:target_type] =  check_point_type(to) || options[:target_type]
			options = {:time => Time.now, :depth => 0, :include_coords => true, :limit => 2}.merge(options)
			options[:time] = options[:time] + 10.minutes # Ansonsten liegt die letzte Verbindung in der Vergangenheit			
			page = @agent.get @@options[:url_route]
			
			result = submit_form page.forms.first, from, to, options		
			
			routes = []
			links = result.links_with(:href => /details=opened!/)
			links.each do |link|
			  page = link.click
			  routes << Route.new(page, options)
			  break if routes.count == options[:limit]
			end
			
			# Keine Station gefunden und es werden keine Vorschläge angezeigt... 
			# also suchen wir nach der nächstbesten Adresse/Station und nutzen diese
			if links.count == 0 && options[:depth] == 0 
				if options[:start_type] == :address
					from = find_address(from, options).name
				elsif options[:start_type] == :station
					from = find_station(from, options).name
				end
				
				if options[:target_type] == :address
					to = find_address(to, options).name
				elsif options[:target_type] == :station
					to = find_station(to, options).name
				end

				return get_routes from, to, options.merge(:depth => options[:depth]+1)
			end
			
			raise "no_route" if routes.count == 0 || links.count == 0			
			routes
		end
		
		# Find the first best station by name
		# Example:
		# 	Input: HH Allee Düsseldorf
		# 	Output: Heinrich-Heine-Allee U, Düsseldorf
		def find_station name, options={}
			val = get_address_or_station(name, :station)
			options[:coords] = name.coordinates if name.respond_to?(:coordinates)
			result = @agent.get("#{@@options[:uri_stations]}#{val}").body.gsub("SLs.sls=", "").gsub(";SLs.showSuggestion();", "")
			find_nearest_station result, options
		end
		
		# Finds the first usable address for the given parameter. The returned address can then be used for further processing in routes
		# Example: 
		# 	Input: Roßstr. 41 40476 Düsseldorf 
		# 	Output: Düsseldorf - Golzheim, Rossstraße 41
		def find_address address, options={}
			val = get_address_or_station(address, :address)
			options[:coords] = address.coordinates if address.respond_to?(:coordinates)
			result = @agent.get("#{@@options[:uri_adresses]}#{val}").body.gsub("SLs.sls=", "").gsub(";SLs.showSuggestion();", "")
			find_nearest_station result, options
		end
		
		############################################################################################
		private
		############################################################################################
		
		def find_nearest_station result, options={}
			# a Mechanize::File instead of a Page is returned so we have to convert manually
			result = encode result
			result = JSON.parse(result)["suggestions"]

			if options[:coords].nil?
				s = Station.new(result.first)
			else
				result.map!{|r| Station.new(r)}
				result.each {|s| s.distance = Geocoder::Calculations.distance_between(options[:coords], s)}
				result.sort! {|a,b| a.distance <=> b.distance}
				s = result.first
			end

			s
		end
		
		def encode str
			if str.respond_to? :encode
				str.force_encoding("iso-8859-1").encode("utf-8")
			else
				Iconv.conv("utf-8", "iso-8859-1", str)
			end
		end
		
		def check_point_type geocoder_result
			return nil unless geocoder_result.is_a? Geocoder::Result::Base
			return :address unless geocoder_result.address_components.index{|a| a["types"].include?("route")}.nil?
			return :station if geocoder_result.address_components.index{|a| a["types"].include?("train_station") || a["types"].include?("transit_station")}.nil?
			return :station
		end
		
		def get_address_or_station geocoder_result, type
			return geocoder_result.to_s unless geocoder_result.is_a? Geocoder::Result::Base
			addy = geocoder_result.address
			if type == :station
				begin
					addy = geocoder_result.address_components.find{|a| a["types"].include? "transit_station"}["short_name"]
					addy += " #{geocoder_result.city}" unless addy.include?(geocoder_result.city)
				rescue StandardError
				end
			end
			addy
		end
		
		def submit_form form, from, to, options
			form["REQ0JourneyDate"] = options[:time].strftime "%d.%m.%y"
			form["REQ0JourneyTime"] = options[:time].to_formatted_s :time
			form["REQ0JourneyStopsS0A"] = TYPES[options[:start_type]]
			form["REQ0JourneyStopsZ0A"] = TYPES[options[:target_type]]
			form["REQ0JourneyStopsS0G"] = get_address_or_station(from, options[:start_type])
			form["REQ0JourneyStopsZ0G"] = get_address_or_station(to, options[:target_type])
			form["REQ0JourneyProduct_prod_list"] = "4:0001111111000000"
			form.submit(form.button_with(:value => "Suchen"))
		end
	end
end