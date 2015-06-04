require "rubygems"
require "rubygems/package_task"

Gem::PackageTask.new(eval(File.read("geminabox.gemspec"))) do |pkg|
end

desc 'Clear out generated packages'
task :clean => [:clobber_package]

require 'rake/testtask'

Rake::TestTask.new("test:integration") do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/integration/**/*_test.rb"
end

Rake::TestTask.new("test:smoke:paranoid") do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/smoke_test.rb"
end

desc "Run the smoke tests, faster."
task "test:smoke" do
  $:.unshift("lib").unshift("test")
  require "smoke_test"
end

%w{ units requests system }.each do |name|
  Rake::TestTask.new("test:#{name}") do |t|
    t.libs << "test" << "lib"
    t.pattern = "test/#{name}/**/*_test.rb"
  end 
end

task :st => "test:smoke"
task :test => ["test:units", "test:requests", "test:integration", "test:system"]
task :default => :test
