require "rubygems"
require "rubygems/package_task"
require "rdoc/task"
require "rspec/core/rake_task"

desc "Run Specs"
task :spec do
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = "spec/*_spec.rb"
  end
end

task :default => :package

Gem::PackageTask.new(eval(File.read("geminabox.gemspec"))) do |pkg|
end

Rake::RDocTask.new do |rd|
  rd.main = "README.markdown"
  rd.rdoc_files.include("README.markdown", "lib/**/*.rb")
  rd.rdoc_dir = "rdoc"
end

desc 'Clear out RDoc and generated packages'
task :clean => [:clobber_rdoc, :clobber_package]
