require 'test/unit'
require 'bahn'

class BahnTest < Test::Unit::TestCase
	def setup
		@agent = Bahn::Agent.new
	end
	
	## use this to show the routes output
	#def teardown
	#	@routes.each {|route| route.parts.each {|part| puts part } }
	#	puts "Hinweise: #{@routes.first.notes}"
	#end
	
	def test_station_2_address
		@routes = @agent.get_routes(
			"Düsseldorf reisholz s bahn", 
			"Düsseldorf, Heerdter Sandberg 40 ",	
			:include_coords => true, 
			:limit => 1,
			:start_type => :station,
			:target_type => :address)
		assert_equal "Düsseldorf-Reisholz (51.180443,6.861358)", @routes.first.start.to_s
		assert_equal "Düsseldorf - Oberkassel, Heerdter Sandberg 40 (51.236059,6.737504)", @routes.first.target.to_s
		assert_equal "Fußweg", @routes.first.parts.last.type
	end		
	
	def test_address_2_station
		@routes = @agent.get_routes(
			"Düsseldorf, Heerdter Sandberg 40 ", 			
			"Benrath ddorf", 
			:include_coords => true, 
			:limit => 1,
			:start_type => :address,
			:target_type => :station)
		assert_equal "Düsseldorf - Oberkassel, Heerdter Sandberg 40 (51.236059,6.737504)", @routes.first.start.to_s
		assert_equal "Fußweg", @routes.first.parts.first.type
		assert_equal "Düsseldorf-Benrath (51.162375,6.879040)", @routes.first.target.to_s
	end		
	
	def test_station_2_station
		@routes = @agent.get_routes(
			"Düsseldorf hbf", 
			"Düsseldorf - Heerdter Sandberg U", 			
			:include_coords => true, 
			:limit => 1,
			:start_type => :station,
			:target_type => :station)
		assert_equal "Düsseldorf Hauptbahnhof (51.219960,6.794316)", @routes.first.start.to_s
		assert_equal "Heerdter Sandberg U, Düsseldorf (51.236509,6.739042)", @routes.first.target.to_s
	end		
	
	def test_address_2_address
		@routes = @agent.get_routes(
			"Düsseldorf Winkelsfelder str. 60", 
			"Düsseldorf, Heerdter Sandberg 40 ", 			
			:include_coords => true, 
			:limit => 1,
			:start_type => :address,
			:target_type => :address)
		assert_equal "Düsseldorf - Pempelfort, Winkelsfelder Straße 45 (51.239772,6.785902)", @routes.first.start.to_s
		assert_equal "Düsseldorf - Oberkassel, Heerdter Sandberg 40 (51.236059,6.737504)", @routes.first.target.to_s
		assert_equal "Fußweg", @routes.first.parts.last.type
		assert_equal "Fußweg", @routes.first.parts.first.type
	end		
end