# encoding: utf-8

module Bahn
  # The whole Route from A to B.
  # This is created from the m.bahn.de detail view page and parses the given data.
  # At the end you'll have a nice step by step navigation
  # Feel free to refactor ;)
  class Route
    attr_accessor :parts, :notes, :start_type, :target_type, :price
    
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
      self.notes = Array.new
      summary_time = page.search("//div[contains(@class, 'querysummary2')]").text.strip
      
      # we'll add it for now...
      #includes = ["Einfache Fahrt", "Preisinformationen", "Weitere Informationen", "Start/Ziel mit äquivalentem Bahnhof ersetzt"]
      #start_withs = ["Reiseprofil", "Hinweis", "Aktuelle Informationen"]
      notes = Array.new
      #notes << page.search("//div[contains(@class, 'haupt rline')]").map(&:text).map(&:strip)
      notes << page.search("//div[contains(@class, 'red bold haupt')]").map(&:text).map(&:strip)
      notes.each do |note|
        self.notes << note if note.size > 0
      end

      self.price = parse_price(page.search("//div[contains(@class, 'formular')]").map(&:text).map(&:strip))

      change = page.search("//div[contains(@class, 'routeStart')]")
      name = station_to_name change

      type = page.search("//div[contains(@class, 'routeStart')]/following::*[1]").text.strip
      last_lines = get_lines(change)

      part = RoutePart.new
      part.type = type
      part.start_time = parse_date(summary_time.split("\n")[0...2].join(" "))
      part.start_time -= last_lines.last.to_i.minutes if options[:start_type] == :address
      part.start_delay = parse_delay(summary_time.split("\n")[0...2].join(" "))
      part.start = Station.new({"value" => name, :load => options[:start_type] == :address ? :foot : :station, :do_load => @do_load})
      part.platform_start = parse_platform(last_lines.last)

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
          part.start_delay = parse_delay(lines.last)
          part.platform_start = parse_platform(lines.last)
          unless lines.first.starts_with?("an")
            @parts.last.end_time = @parts.last.start_time + last_lines.last.to_i.minutes
          end
        end
        
        if lines.first.starts_with?("an")
          @parts.last.end_time = parse_date(lines.first)
          @parts.last.target_delay = parse_delay(lines.first)
          @parts.last.platform_target = parse_platform(lines.first)
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
        @parts.last.target_delay = parse_delay(lines.first)
        @parts.last.platform_target = parse_platform(lines.first)
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

    # Duration of a route in seconds
    def duration
      start = start_time.to_i
      end_with_delay = end_time.to_i + (@parts.last.target_delay * 1.minutes)

      end_with_delay - start
    end

    # Starting point of the route
    def start
      @parts.first.start
    end
    
    # Target point of the route
    def target
      @parts.last.target
    end

    def has_delay?
      @parts.any? { |part| (part.start_delay > 0 || part.target_delay > 0) }
    end
    
    private
    
    def station_to_name change
      change.search("span").select{|s| s.attributes["class"].value != "red"}.inject(" "){|r, s| r << s.text}.strip.gsub(/\+\d+/, "")
    end
    
    def get_lines change
      change.text.split("\n").reject{|s| s.to_s.length == 0}
    end

    def parse_price(to_parse)
      return Array.new unless to_parse.first.match("EUR")
      tags = to_parse.uniq.map { |p| p.split(/\d+\,\d{1,2}.EUR/) }.flatten
      tags.map! { |t| t.gsub(/\p{Space}/, " ").strip } # remove ugly whitespaces: ruby >= 1.9.3
      prices = to_parse.uniq.map { |p| p.scan(/\d+\,\d{1,2}.EUR/) }.flatten.map { |p| p.gsub(",",".").to_f }
      price_information = Array.new
      (0...prices.size).each do |idx|
        price_information << {
          :price => prices[idx],
          :class => tags[idx+1].scan(/\d\.\sKlasse/).first.scan(/\d/).first,
          :details => tags[idx+1].split(/\d\.\sKlasse/).last
        }
      end

      return price_information
    end

    def parse_platform(to_parse)
      return to_parse.split("Gl.").last.strip if to_parse.match("Gl.")
      return nil
    end

    def parse_delay(to_parse)
      to_parse = to_parse.split("+") # + sign indicates delay information

      if to_parse.size > 1 # extract delay information
        delay_information = to_parse.last.split.first.to_i
      else
        delay_information = 0
      end
      return delay_information
    end

    def parse_date to_parse
      to_parse = to_parse.split("+") # clears time errors e.g.: "an 18:01 +4 Gl. 17"

      # fix number of year digits from 2 to 4
      to_parse = to_parse.first.gsub(".#{DateTime.now.year.to_s[2..4]} ", ".#{DateTime.now.year.to_s} ")

      # fix missing year information in route parts (interesting for
      # past or future connections)
      unless to_parse.match(/\d{1,2}\.\d{1,2}\.\d{4}/)
        tmp_date = DateTime.parse(to_parse[/\d{1,2}:\d{1,2}/])

        tmp_date = DateTime.new(self.start_time.year, 
                                self.start_time.month, 
                                self.start_time.day,
                                tmp_date.hour, 
                                tmp_date.min, 
                                tmp_date.sec)

        tmp_date = tmp_date +1 if tmp_date < self.start_time
        to_parse = tmp_date.to_s
      end

      to_parse = DateTime.parse(to_parse).to_s

      # fix timezone
      time_zone = DateTime.now.in_time_zone("Berlin").strftime("%z")
      to_parse = to_parse.gsub("+00:00", time_zone).gsub("+0000", time_zone)
      return DateTime.parse(to_parse)
    end
  end
end
