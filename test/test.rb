# encoding: utf-8

require 'test/unit'
require 'bahn'
require 'geocoder'


class BahnTest < Test::Unit::TestCase
  def setup
    @agent = Bahn::Agent.new
  end
  
  def test_station_2_address
    @routes = @agent.get_routes(
                                Geocoder.search("Düsseldorf reisholz bahnhof").first, 
                                Geocoder.search("Düsseldorf, Heerdter Sandberg 40 ").first,	
                                :include_coords => true, 
                                :limit => 1)
    assert @routes.first.start.to_s.include?("Reisholz"), "but was #{@routes.first.start}"
    assert @routes.first.start.to_s.include?("Düsseldorf"), "but was #{@routes.first.start}"
    assert_equal "Düsseldorf - Oberkassel, Heerdter Sandberg 40 (51.236059,6.737504)", @routes.first.target.to_s
    assert_equal "Fußweg", @routes.first.parts.last.type
  end		
  
  def test_address_2_station
    @routes = @agent.get_routes(
                                Geocoder.search("Düsseldorf, Heerdter Sandberg 40 ").first, 			
                                Geocoder.search("Benrath ddorf").first, 
                                :include_coords => true, 
                                :limit => 1)
    assert_equal "Düsseldorf - Oberkassel, Heerdter Sandberg 40 (51.236059,6.737504)", @routes.first.start.to_s
    assert_equal "Fußweg", @routes.first.parts.first.type
    assert @routes.first.target.to_s.include?("Düsseldorf"), "but was #{@routes.first.target}"
    assert @routes.first.target.to_s.include?("Benrath"), "but was #{@routes.first.target}"
  end		
  
  def test_station_2_station
    @routes = @agent.get_routes(
                                Geocoder.search("Düsseldorf hbf").first, 
                                Geocoder.search("Düsseldorf - Heerdter Sandberg U").first, 			
                                :include_coords => true, 
                                :limit => 1)
    assert_equal "Düsseldorf Hauptbahnhof (51.219960,6.794316)", @routes.first.start.to_s
    assert_equal "Heerdter Sandberg U, Düsseldorf (51.236509,6.739042)", @routes.first.target.to_s
  end		
  
  
  def test_station_2_station_2
    @routes = @agent.get_routes(
                                Geocoder.search("Düsseldorf hbf").first, 
                                Geocoder.search("Düsseldorf Heerdter Sandberg").first, 			
                                :include_coords => true, 
                                :limit => 1)
    assert_equal "Düsseldorf Hauptbahnhof (51.219960,6.794316)", @routes.first.start.to_s
    assert_equal "Heerdter Sandberg U, Düsseldorf (51.236509,6.739042)", @routes.first.target.to_s
  end		
  
  
  def test_address_2_address
    @routes = @agent.get_routes(
                                Geocoder.search("Düsseldorf Winkelsfelder str. 60").first, 
                                Geocoder.search("Düsseldorf, Heerdter Sandberg 40 ").first, 			
                                :include_coords => true, 
                                :limit => 1)
    assert_equal "Düsseldorf - Pempelfort, Winkelsfelder Straße 45 (51.239772,6.785902)", @routes.first.start.to_s
    assert_equal "Düsseldorf - Oberkassel, Heerdter Sandberg 40 (51.236059,6.737504)", @routes.first.target.to_s
    assert_equal "Fußweg", @routes.first.parts.last.type
    assert_equal "Fußweg", @routes.first.parts.first.type
  end
  
  def test_station_wrong_location
    @routes = @agent.get_routes(
                                Geocoder.search("Prenzlauer Berg, Berlin, Germany").first,
                                Geocoder.search("Berlin Hauptbahnhof").first,
                                :include_coords => true, 
                                :limit => 1
                                )
    
    assert @routes.first.start.to_s.starts_with?("Prenzlauer"), "but was #{@routes.first.start.to_s}"
    assert @routes.first.target.to_s.starts_with?("Berlin Hbf"), "but was #{@routes.first.target.to_s}"
    assert @routes.first.parts.last.target.to_s.starts_with?("Berlin Hbf"), "but was #{@routes.first.parts.last.target.to_s}"
  end
  
  # ss and ß make problems sometimes, so here we test if the start is 
  # at least the street right next to the correct street
  def test_rossstr_duesseldorf
    @routes = @agent.get_routes(
                                Geocoder.search("Düsseldorf Roßstraße 42 düsseldorf").first, 
                                Geocoder.search("Düsseldorf, Heerdter Sandberg 40 ").first, 			
                                :include_coords => true, 
                                :limit => 1)
    assert_equal "Düsseldorf - Derendorf, Römerstraße 2-27 (51.245075,6.783080)", @routes.first.start.to_s
    assert_equal "Düsseldorf - Oberkassel, Heerdter Sandberg 40 (51.236059,6.737504)", @routes.first.target.to_s
  end
  
  def test_koe_to_due
    @routes = @agent.get_routes(
                                Geocoder.search("Domstraße, 50668 Köln, Deutschland").first,
                                "Heerdter Sandberg, 40549 Düsseldorf, Deutschland",
                                :target_type => :station,
                                :include_coords => true,
                                :limit => 1
                                )
    
    assert @routes.first.start.to_s.include?("Köln"), "was #{@routes.first.start}"
    assert @routes.first.target.to_s.include?("Düsseldorf"), "was #{@routes.first.target}"
  end
  
  def test_muc_to_muc
    @routes = @agent.get_routes(
                                Geocoder.search("Clemensstraße, München, Deutschland").first, 
                                Geocoder.search("Am Eisbach 4, 0538 München, Deutschland").first, 			
                                :include_coords => true, 
                                :limit => 1)
    
    assert_equal "Clemensstraße, München (48.163492,11.574465)", @routes.first.start.to_s
    assert_equal "München - Schwabing, Am Eisbach 4 (48.154494,11.600291)", @routes.first.target.to_s
  end

  def test_platform
    @routes = @agent.get_routes(
                                Geocoder.search("München Hbf").first,
                                Geocoder.search("Berlin Hbf").first,
                                :target_type => :station,
                                :include_coords => true,
                                :limit => 1,
                                :time => Time.now + 86400
                                )

    my_platforms = @routes.first.parts.map { |p| [ p.platform_start, p.platform_target] }.flatten
    
    assert(my_platforms.all?, "Expexted all platforms to be defined")
    assert(my_platforms.map { |p| p.size }.all? { |s| s>0 && s < 5} , "Expected platform identifiers to be between 1 and 4 characters")
  end

  def test_price
    @routes = @agent.get_routes(
                                Geocoder.search("München Hbf").first,
                                Geocoder.search("Berlin Hbf").first,
                                :target_type => :station,
                                :include_coords => true,
                                :limit => 1,
                                :time => Time.now + 86400
                                )
    
    assert(@routes.first.price.first[:price].class == Float, "Expexted price of price information is of type Float")
    assert(@routes.first.price.first[:class].class == String, "Expexted class of price information is of type String")
    assert(@routes.first.price.first[:details].class == String, "Expexted details of price information is of type String")
  end

end
