module Bahn
	$KCODE = 'U'
	
	class Agent	
		@@options = {
			:url_route => 'http://mobile.bahn.de/bin/mobil/query.exe/dox?country=DEU&rt=1&use_realtime_filter=1&searchMode=ADVANCED'
		}

		def get_routes from, to, options = {}
			options = {:time => Time.now}.merge(options)
			agent = Mechanize.new
			page = agent.get @@options[:url_route]
			form = page.forms.first
			
			# Datum / Zeit		
			form.field_with(:name => "REQ0JourneyDate").value = "#{options[:time].day}.#{options[:time].month}.#{options[:time].year-2000}"
			form.field_with(:name => "REQ0JourneyTime").value = "#{options[:time].hour}:#{options[:time].min}"

			# Straße / Adresse
			form.field_with(:name => "REQ0JourneyStopsS0A").value = 2
			form.field_with(:name => "REQ0JourneyStopsZ0A").value = 2
			form.field_with(:name => "REQ0JourneyStopsS0G").value = from
			form.field_with(:name => "REQ0JourneyStopsZ0G").value = to
			
			result = form.submit form.buttons.first
			
			routes = []
			links = result.links_with(:href => /details=opened!/)
			links.each  do |link|
			  page = link.click 
			  routes << Route.new(page)
			end
			
### todo remove / handle exception
puts page.body if links.count == 0
###
			
			raise "No route found" if links.count == 0			
			routes
		end
	end
end