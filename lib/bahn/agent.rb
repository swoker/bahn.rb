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
	#		=> Am 2013-02-01 von 17:32 bis 17:33 : Düsseldorf - Oberkassel, Heerdter Sandberg 35 nach Heerdter Sandberg U, Düsseldorf via Fußweg
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
		
		# Initialize a new Agent
		# options:
		#  :user_agent => Set the user agent. Default: "bahn.rb"
		def initialize options = {}
			options = {:user_agent => "bahn.rb", :logger => false}.merge(options)
			@agent = Mechanize.new
			@agent.user_agent = options[:user_agent]
		end
		
		# Get the next few routes with public transportation from A to B.
		#
		# :start_type and :target_type should be the same, no other options is implemented yet
		# Options:
		# 	* :time => start time for the connection
		# 	* :start_type => 1 = station, 2 = address
		# 	* :target_type => 1 = station, 2 = address
		# Returns:
		# 	Array of Bahn::Route(s)
		# Raises:
		# 	"no_route" if no route could be found
		def get_routes from, to, options = {}
			options = {:time => Time.now, :start_type => 2, :target_type => 2, :depth => 0}.merge(options)
			page = @agent.get @@options[:url_route]
			form = page.forms.first
			form["REQ0JourneyDate"] = "#{options[:time].day}.#{options[:time].month}.#{options[:time].year-2000}"
			form["REQ0JourneyTime"] = "#{options[:time].hour}:#{options[:time].min}"
			form["REQ0JourneyStopsS0A"] = options[:start_type]
			form["REQ0JourneyStopsZ0A"] = options[:target_type]
			form["REQ0JourneyStopsS0G"] = from
			form["REQ0JourneyStopsZ0G"] = to			
			result = form.submit(form.button_with(:value => "Suchen"))
			
			type = :undefined
			type = :door2door if options[:start_type] == 2 && options[:target_type] == 2
			type = :station2station if options[:start_type] == 1 && options[:target_type] == 1

			routes = []
			links = result.links_with(:href => /details=opened!/)
			links.each  do |link|
			  page = link.click 
			  routes << Route.new(page, type)
			end
			
			# Keine Station gefunden und es werden keine Vorschläge angezeigt... 
			# also suchen wir nachder nächstbesten Adresse und nutzen dies
			if links.count == 0 && options[:depth] == 0 && type == :door2door
				from = find_address from
				to = find_address to
				return get_routes from, to, {:time => options[:time], :depth => options[:depth]+1}
			end
			
			raise "no_route" if links.count == 0			
			routes
		end
		
		# Find the first best station by name
		# Example:
		# 	Input: HH Allee Düsseldorf
		# 	Output: Heinrich-Heine-Allee U, Düsseldorf
		def find_station name		
			result = @agent.get("#{@@options[:uri_stations]}#{name}").body.gsub("SLs.sls=", "").gsub(";SLs.showSuggestion();", "")
			# a Mechanize::File instead of a Page is returned so we have to convert manually
			result = Iconv.conv("utf-8", "iso-8859-1", result)
			r = JSON.parse(result)["suggestions"].first["value"]
		end
		
		# Finds the first usable address for the given parameter. The returned address can then be used for further processing in routes
		# Example: 
		# 	Input: Roßstr. 41 40476 Düsseldorf 
		# 	Output: Düsseldorf - Golzheim, Rossstraße 41
		def find_address address		
			result = @agent.get("#{@@options[:uri_adresses]}#{address}").body.gsub("SLs.sls=", "").gsub(";SLs.showSuggestion();", "")
			# a Mechanize::File instead of a Page is returned so we have to convert manually
			result = Iconv.conv("utf-8", "iso-8859-1", result)
			JSON.parse(result)["suggestions"].first["value"]
		end
	end
end