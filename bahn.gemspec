require 'base64'

Gem::Specification.new do |s|
  s.name = "bahn.rb"
  s.version = "2.1.0"
  s.platform = Gem::Platform::RUBY
  s.authors = ["Simon Woker"]
  s.email = Base64.decode64("Z2l0aHViQHNpbW9ud29rZXIuZGU=\n")
  s.homepage = "https://github.com/swoker/bahn.rb"
  s.summary = "Bahn ÖPNV information"
  s.description = "Load connections for public transportation from the m.bahn.de website."

  s.required_rubygems_version = ">= 1.3.6"

  # If you have other dependencies, add them here
  s.add_runtime_dependency "json", ["~> 1.6"]
  s.add_runtime_dependency "mechanize"
  s.add_runtime_dependency "activesupport"
  s.add_development_dependency "rake", [">= 0"]

  # If you need to check in files that aren't .rb files, add them here
  s.files = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.md"]
  s.require_path = 'lib'
end
