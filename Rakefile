require "rubygems"
require "rubygems/package_task"
require "bundler/gem_tasks"

spec = Gem::Specification.load("geminabox.gemspec")
Gem::PackageTask.new(spec) do |pkg|
end

desc 'Clear out generated packages'
task :clean => [:clobber_package]

require 'rake/testtask'

Rake::TestTask.new("test:integration") do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/integration/**/*_test.rb"
  t.warning = nil
end

Rake::TestTask.new("test:smoke:paranoid") do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/smoke_test.rb"
  t.warning = nil
end

desc "Run the smoke tests, faster."
task "test:smoke" do
  $:.unshift("lib").unshift("test")
  require "smoke_test"
end

Rake::TestTask.new("test:requests") do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/requests/**/*_test.rb"
  t.warning = nil
end

Rake::TestTask.new("test:units") do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/units/**/*_test.rb"
  t.warning = nil
end

# Runs the rubygems compact-index conformance suite against a live geminabox.
# Kept out of the default :test run because it shells out to the external
# gem_server_conformance RSpec CLI; CI drives it as its own job.
Rake::TestTask.new("test:conformance") do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/conformance/**/*_test.rb"
  t.warning = nil
end

task :st => "test:smoke"
task :test => ["test:units", "test:requests", "test:integration"]
task :default => :test


desc 'Open an irb session preloaded with the gem library'
task :console do
  require "irb"
  require "geminabox"
  ARGV.shift
  IRB.start
end
task :c => :console
