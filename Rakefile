require "rubygems"
require "rubygems/package_task"
require "bundler/gem_tasks"

Gem::PackageTask.new(eval(File.read("geminabox.gemspec"))) do |pkg|
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

task :st => "test:smoke"
task :test => ["test:units", "test:requests", "test:integration"]
task :default => :test


desc 'Open an irb session preloaded with the gem library'
task :console do
  sh 'irb -I lib -r geminabox.rb'
end
task :c => :console
