Load connections for public transportation from the m.bahn.de website.

This is under heavy development. Don't expect a working solution!

Example
=
	require 'bahn.rb'
	
	agent =  Bahn::Agent.new
	routes = agent.get_routes(
		"Düsseldorf reisholz s bahn", 	# start address or station
		"Düsseldorf, Heerdter Sandberg 40 ",	# target address or station
		:include_coords => true, # include coordinates of stations
		:limit => 1,	# how many connections?
		:start_type => :station, # :station or :address
		:target_type => :address # :station or :address
		)
	# output the connection info
	routes.each {|route| route.parts.each {|part| puts part } }

How to help
=
Feel free to implement some additions, refactor and create a pull request!
... and create tests of course ;)