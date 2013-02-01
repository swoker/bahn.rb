
require './lib/bahn.rb'
require 'logger'

start = Time.now


agent = Bahn::Agent.new
routes = agent.get_routes "Heerdter Sandberg 35 Düsseldorf, Düsseldorf", "Berlin Hauptstraße 10"
routes.each {|route| route.parts.each {|part| puts part } }

puts "Dauer: #{Time.now - start} Sekunden"

#############
#	example output:

#	Am 2013-01-31 von 17:03 bis 17:06 : Düsseldorf - Oberkassel, Heerdter Sandberg 35 nach Heerdter Sandberg U, Düsseldorf via Fußweg
#	Am 2013-01-31 von 17:06 bis 17:18 : Heerdter Sandberg U, Düsseldorf nach Oststraße U, Düsseldorf via U 76
#	Am 2013-01-31 von 17:22 bis 17:31 : Oststraße U, Düsseldorf nach Münsterstr./Feuerwache, Düsseldorf via Bus SB5
#	Am 2013-01-31 von 17:31 bis 17:35 : Münsterstr./Feuerwache, Düsseldorf nach Düsseldorf - Pempelfort, Winkelsfelder Straße 40 via Fußweg
#	---------------------------
#	Am 2013-01-31 von 17:12 bis 17:20 : Düsseldorf - Oberkassel, Heerdter Sandberg 35 nach Niederkasseler Kirchweg, Düsseldorf via Fußweg
#	Am 2013-01-31 von 17:20 bis 17:26 : Niederkasseler Kirchweg, Düsseldorf nach Nordfriedhof, Düsseldorf via Bus 834
#	Am 2013-01-31 von 17:30 bis 17:37 : Nordfriedhof, Düsseldorf nach Münsterstr./Feuerwache, Düsseldorf via Bus 721
#	Am 2013-01-31 von 17:37 bis 17:41 : Münsterstr./Feuerwache, Düsseldorf nach Düsseldorf - Pempelfort, Winkelsfelder Straße 40 via Fußweg
