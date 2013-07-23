# encoding: utf-8

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
      :uri_stations => 'http://reiseauskunft.bahn.de/bin/ajax-getstop.exe/en?REQ0JourneyStopsS0A=1&REQ0JourneyStopsS0G=',
      :uri_stations_near => 'http://mobile.bahn.de/bin/mobil/query.exe/dox?ld=9627&n=1&rt=1&use_realtime_filter=1&performLocating=2&tpl=stopsnear&look_maxdist=1000&look_stopclass=1023&look_y=%i&look_x=%i'
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

    TIME_RELATION =
      {
      :arrival => 0,
      :depature => 1
    }.freeze

    JOURNEY_PRODUCT_PRESETS = {
      :alle => "1:1111111111000000",
      :alle_ohne_ice => "2:0111111111000000",
      :nur_nahverkehr => "4:0001111111000000",
    }.freeze
    
    # Initialize a new Agent
    # options:
    #  :user_agent => Set the user agent. Default: "bahn.rb"
    def initialize
      @agent = Mechanize.new
      @agent.set_defaults if @agent.respond_to?(:set_defaults)
      @agent.user_agent = @@user_agent ||= "bahn.rb"
    end
    
    # Get the next few routes with public transportation from A to B.
    #
    # Options:
    #   * :time => start time for the connection
    #   * :include_coords => Include coordiantes for the station. This takes a while especially for longer routes! default: true
    # Returns:
    #   Array of Bahn::Route(s)
    # Raises:
    #   "no_route" if no route could be found
    def get_routes from, to, options = {}
      options[:start_type] = check_point_type(from) || options[:start_type]
      options[:target_type] =	check_point_type(to) || options[:target_type]
      options = {:time => Time.now, :depth => 0, :include_coords => true, :limit => 2}.merge(options)
      options[:time] = options[:time].in_time_zone("Berlin") + 10.minutes # Ansonsten liegt die erste Verbindung in der Vergangenheit
      page = @agent.get @@options[:url_route]
      
      result = submit_form page.forms.first, from, to, options		
      
      routes = []
      links = result.links_with(:href => /details=opened!/).select { |l| l.to_s.size > 0} # only select connection links, no warning links
      links.each do |link|
        page = link.click
        routes << Route.new(page, options)
        break if routes.count == options[:limit]
      end
      
      # Keine Station gefunden also suchen wir nach der nächstbesten Adresse/Station
      if links.count == 0 && options[:depth] == 0
        if options[:start_type] == :address
          from = find_address(from, options)
          options[:start_type] = from.station_type
          from = from.name
        elsif options[:start_type] == :station
          from = find_station(from, options)
          options[:start_type] = from.station_type
          from = from.name
        end
        
        if options[:target_type] == :address
          to = find_address(to, options)
          options[:target_type] = to.station_type
          to = to.name
        elsif options[:target_type] == :station
          to = find_station(to, options)
          options[:target_type] = to.station_type
          to = to.name
        end
        
        return get_routes from, to, options.merge(:depth => options[:depth]+1)
      end
      
      raise "no_route" if routes.count == 0 || links.count == 0			
      routes
    end
    
    # Find the first best station by name
    # Example:
    #   Input: HH Allee Düsseldorf
    #   Output: Heinrich-Heine-Allee U, Düsseldorf
    def find_station name, options={}
      val = get_address_or_station(name, :station)
      options[:coords] = name.respond_to?(:coordinates) ? name.coordinates : nil
      result = @agent.get("#{@@options[:uri_stations]}#{val}").body.gsub("SLs.sls=", "").gsub(";SLs.showSuggestion();", "")
      options[:current_station_type] = :station
      options[:searched_name] = name
      find_nearest_station result, options
    end
    
    # Finds the first usable address for the given parameter. The returned address can then be used for further processing in routes
    # Example: 
    #   Input: Roßstr. 41 40476 Düsseldorf 
    #   Output: Düsseldorf - Golzheim, Rossstraße 41
    def find_address address, options={}
      val = get_address_or_station(address, :address)
      options[:coords] = address.respond_to?(:coordinates) ? address.coordinates : nil
      result = @agent.get("#{@@options[:uri_adresses]}#{val}").body.gsub("SLs.sls=", "").gsub(";SLs.showSuggestion();", "")
      options[:current_station_type] = :address
      find_nearest_station result, options
    end
    
    def find_station_at lat, lon, options={}
      uri = @@options[:uri_stations_near] % [(lat * 1000000), (lon * 1000000)]
      result = @agent.get(uri)
      stations = result.links.select{|l| l.href.include?("HWAI=STATION!")}.map do |link|
        s = Station.new({:do_load => false})
        s.name = link.text
        lat_match = link.href.match(/Y=(\d{7,})/)
        s.lat = lat_match[1].insert(-7, ".") unless lat_match.nil?
        lon_match = link.href.match(/X=(\d{7,})/)
        s.lon = lon_match[1].insert(-7, ".") unless lon_match.nil?
        # not needed but hey, since we got it ;)
        dist_match = link.href.match(/dist=(\d+)!/)
        s.distance = (dist_match[1].to_i / 1000) unless dist_match.nil? # meter to km
        s.station_type = :station
        s
      end
      
      # prefer HBF or Hauptbahnhof if there is one nearby
      station = stations.select{|s| s.name.include?("Hauptbahnhof") || s.name.include?("HBF")}.first
      return (station.nil? ? stations.first : station)
    end
    
    ############################################################################################
    private
    ############################################################################################
    
    def find_nearest_station result, options={}
      # a Mechanize::File instead of a Page is returned so we have to convert manually
      result = encode result
      result = JSON.parse(result)["suggestions"]

      stations = result.map{|r| (Station.new(r) rescue StandardError) }.compact
      stations = stations.delete_if{|s| s.instance_of?(StandardError)}
      station = options[:searched_name].to_s.length > 0 ? stations.select{|s| s.name == options[:searched_name]}.first : nil
      if options[:coords].nil?        
        station = stations.first if station.nil?
        station.station_type = options[:current_station_type]
      elsif station.nil? # 100% match not found, so look for the next best match
        stations.each {|s| s.distance = Geocoder::Calculations.distance_between(options[:coords], s, :units => :km)}
        stations.sort! {|a,b| a.distance <=> b.distance}
        station = stations.first
        station.station_type = options[:current_station_type]
        
        # more than 1 km? This seems to be wrong...
        if station.distance > 1
          nearest_station = find_station_at options[:coords][0], options[:coords][1]
          station = nearest_station if nearest_station
        end
      end
      station
    end
    
    def encode str
      if str.respond_to? :encode
        str.force_encoding("iso-8859-1").encode("utf-8")
      else
        Iconv.conv("utf-8", "iso-8859-1", str)
      end
    end
    
    def encode_to_iso str
      if str.respond_to? :encode
        str.encode("iso-8859-1")
      else
        Iconv.conv("iso-8859-1", "utf-8", str)
      end
    end
    
    def check_point_type geocoder_result
      return nil unless geocoder_result.respond_to?(:types)
      return :station if geocoder_result.types.include?("transit_station") # subway, bus, ...
      
      return :address if geocoder_result.types.include?("street_address") # full address
      return :address if geocoder_result.types.include?("route") # street name only
      return :address if geocoder_result.types.include?("postal_code") # plz only
      
      # city without transit station => use address + HBF
      if geocoder_result.types.include?("locality") && geocoder_result.transit_station.to_s.length == 0
        geocoder_result.transit_station = geocoder_result.address.gsub(", Deutschland", "").gsub(", Germany", "")
        geocoder_result.transit_station << " HBF"
        return :station
      end
      
      # (sub-)locality or political or anything else => treat as station (most likely main station)
      return :station
    end
    
    def get_address_or_station geocoder_result, type
      return geocoder_result.to_s unless geocoder_result.respond_to?(:address)			
      addy = ""
      
      if type == :station
        addy = geocoder_result.transit_station if geocoder_result.respond_to?(:transit_station)
        
        if geocoder_result.respond_to?(:address_components_of_type)
          begin
            addy = geocoder_result.address_components_of_type("transit_station").first["short_name"]
            addy += " #{geocoder_result.city}" unless addy.include?(geocoder_result.city)
          rescue StandardError
            # use address instead
          end
        end
      end
      
      if addy.to_s.empty?
        addy = geocoder_result.address
      end
      
      addy
    end
    
    def submit_form form, from, to, options
      form["REQ0JourneyDate"] = options[:time].strftime "%d.%m.%y"
      form["REQ0JourneyTime"] = options[:time].to_formatted_s :time
      form["REQ0JourneyStopsS0A"] = TYPES[options[:start_type]]
      form["REQ0JourneyStopsZ0A"] = TYPES[options[:target_type]]
      form["REQ0JourneyStopsS0G"] = encode_to_iso(get_address_or_station(from, options[:start_type]))
      form["REQ0JourneyStopsZ0G"] = encode_to_iso(get_address_or_station(to, options[:target_type]))
      form["REQ0HafasSearchForw"] = TIME_RELATION[options[:time_relation]] # 0 -> Abfahrt, 1 -> Ankunft
      form["REQ0JourneyProduct_prod_list"] = JOURNEY_PRODUCT_PRESETS[options[:journey_product]]
      form.submit(form.button_with(:value => "Suchen"))
    end
  end
end
