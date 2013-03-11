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
		assert_equal "Reisholz S-Bahnhof, Düsseldorf (51.180218,6.862437)", @routes.first.start.to_s
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
		assert_equal "Düsseldorf-Benrath (51.162375,6.879040)", @routes.first.target.to_s
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
  
		assert @routes.first.start.to_s.starts_with?("Prenzlauer")
		assert @routes.first.target.to_s.starts_with?("Berlin Hbf")
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
end