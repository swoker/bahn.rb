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
			summary_time = page.search("//div[contains(@class, 'querysummary2')]").text.strip
       
      # we'll add it for now...
      #includes = ["Einfache Fahrt", "Preisinformationen", "Weitere Informationen", "Start/Ziel mit äquivalentem Bahnhof ersetzt"]
      #start_withs = ["Reiseprofil", "Hinweis", "Aktuelle Informationen"]
      notes = page.search("//div[contains(@class, 'haupt rline')]").map(&:text).map(&:strip)      
      
      change = page.search("//div[contains(@class, 'routeStart')]")
      name = station_to_name change
      type = page.search("//div[contains(@class, 'routeStart')]/following::*[1]").text.strip
      last_lines = get_lines(change)

      part = RoutePart.new
      part.type = type
      part.start_time = part.start_time = parse_date(summary_time.split("\n").first)
      part.start_time -= last_lines.last.to_i.minutes if options[:start_type] == :address
      part.start = Station.new({"value" => name, :load => options[:start_type] == :address ? :foot : :station, :do_load => @do_load})
      
      @parts = [part]
      
      page.search("//div[contains(@class, 'routeChange')]").each_with_index do |change, idx|
        part = RoutePart.new
        name = station_to_name change
        type = page.search("//div[contains(@class, 'routeChange')][#{idx+1}]/following::*[1]").text.strip
        lines = change.text.split("\n")
        
        part.type = type
        part.start = Station.new({"value" => name, :load => :station, :do_load => @do_load})
        
        lines = get_lines(change)
        if lines.last.start_with?("ab")
          part.start_time = parse_date(lines.last)
          unless lines.first.starts_with?("an")
            @parts.last.end_time = @parts.last.start_time + last_lines.last.to_i.minutes
          end
        end
        
        if lines.first.starts_with?("an")
          @parts.last.end_time = parse_date(lines.first)          
          unless lines.last.start_with?("ab")
            # Fußweg for part
            part.start_time = @parts.last.end_time
          end
        end
       
        last_lines = lines
        
        @parts.last.target = part.start
        @parts << part #unless @parts.last.start == part.start
      end
      
      
      change = page.search("//div[contains(@class, 'routeEnd')]")
      name = station_to_name change
      @parts.last.target = Station.new({"value" => name, :load => options[:target_type] == :address ? :foot : :station, :do_load => @do_load})
      lines = get_lines(change)

      if lines.first.starts_with?("an")
        @parts.last.end_time = parse_date(lines.first)
      else
        @parts.last.end_time = @parts.last.start_time + last_lines.last.to_i.minutes
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
		
    def station_to_name change
      change.search("span").select{|s| s.attributes["class"].value != "red"}.inject(" "){|r, s| r << s.text}.strip.gsub(/\+\d+/, "")
    end
    
    def get_lines change
      change.text.split("\n").reject{|s| s.to_s.length == 0}
    end
    
    def parse_date to_parse
      to_parse = to_parse.split("+").first # clears time errors e.g.: "an 18:01 +4 Gl. 17"
      to_parse = to_parse.gsub(".#{DateTime.now.year.to_s[2..4]} ", ".#{DateTime.now.year.to_s} ")
      to_parse = DateTime.parse(to_parse).to_s
      time_zone = DateTime.now.in_time_zone("Berlin").strftime("%z")
      to_parse = to_parse.gsub("+00:00", time_zone).gsub("+0000", time_zone)
      DateTime.parse to_parse
    end
	end
end