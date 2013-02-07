require "bundler"
Bundler.setup

require 'rake/testtask'

gemspec = eval(File.read("bahn.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["bahn.gemspec"] do
  system "gem build bahn.gemspec"
  system "gem install bahn-#{Bahn::VERSION}.gem"
end


Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test
