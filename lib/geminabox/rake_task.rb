require 'rake'
require 'rubygems/commands/inabox_command'

desc "Publish to Rally Geminabox server"
namespace :rally do
  task :publish do
    g = Gem::Commands::InaboxCommand.new
    g.options[:overwrite] = true
    g.options[:host] = "http://int-ububld1:9292/"
    g.options[:args] = []
    g.execute
  end
end