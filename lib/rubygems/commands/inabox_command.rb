require 'uri'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'rubygems/command'

class Gem::Commands::InaboxCommand < Gem::Command
  def description
    'Interact with your GemInABox'
  end

  def arguments
    [
     "list           List gems in your GemInABox",
     "delete GEM     Delete GEM from your GemInABox",
     "push GEM       Push GEM to your GemInABox",
    ].join("\n")
  end

  def usage
    "#{program_name} [CMD] <GEM>"
  end

  def initialize
    super 'inabox', description

    add_option('-c', '--configure', "Configure GemInABox") do |value, options|
      options[:configure] = true
    end

    add_option('-g', '--host HOST', "Host to upload to.") do |value, options|
      options[:host] = value
    end

    add_option('-o', '--overwrite', "Overwrite Gem.") do |value, options|
      options[:overwrite] = true
    end
  end

  def last_minute_requires!
    require 'yaml'
    require File.expand_path("../../../geminabox_client.rb", __FILE__)
  end

  def execute
    last_minute_requires!
    return configure if options[:configure]
    configure unless geminabox_host

    if options[:args].size == 0
      say "You didn't specify a gem, looking for one in . and in ./pkg/..."
      gemfiles = [GeminaboxClient::GemLocator.find_gem(Dir.pwd)]
    else
      # Now see what operation we're using
      if options[:args][0] =~ /list/
        # List gems on your GemInABox
        doc = Nokogiri::HTML(open(geminabox_host))
        say "\nListing gems on #{geminabox_host}\n\n"
        doc.search('h2').each do |gem_tag|
          say gem_tag.content
        end
      elsif options[:args][0] =~ /delete/
        # Check for GEM and error if not present
        if options[:args].size == 2
          # Check to see that GEM is on GemInABox
          doc = Nokogiri::HTML(open(geminabox_host))
          geminabox_delete = nil
          doc.search('h2').each do |gem_tag|
            if gem_tag.content.gsub(/[\(\)]/, '').split(' ')[0] =~ /#{options[:args][1]}/
              geminabox_delete = gem_tag.content.gsub(/[\(\)]/, '').split(' ')
            end
          end
          if geminabox_delete == nil
            say "The gem #{options[:args][1]} was not found on #{geminabox_host}"
          else
            # Delete GEM from GemInABox
            uri = URI.parse("#{geminabox_host}/gems/#{geminabox_delete.join('-')}.gem")
            # Shortcut
            response = Net::HTTP.post_form(uri, {"_method" => "DELETE"})
            if response.code.to_i != 303
              say "There has been an error while deleting #{geminabox_delete.join('-')}. Unspecified behaviour may have ocurred."
              puts response.code.inspect
            else
              say "The gem #{geminabox_delete.join('-')} has been deleted from #{geminabox_host}."
            end
          end
        end
      elsif options[:args][0] =~ /push/
        options[:args].delete_at(0)
        gemfiles = get_all_gem_names
        send_gems(gemfiles)
      end
    end
  end

  def send_gems(gemfiles)
    client = GeminaboxClient.new(geminabox_host)

    gemfiles.each do |gemfile|
      say "Pushing #{File.basename(gemfile)} to #{client.url}..."
      begin
        say client.push(gemfile, options)
      rescue GeminaboxClient::Error => e
        alert_error e.message
        terminate_interaction(1)
      end
    end
  end

  def config_path
    File.join(Gem.user_home, '.gem', 'geminabox')
  end

  def configure
    say "Enter the root url for your personal geminabox instance. (E.g. http://gems/)"
    host = ask("Host:")
    self.geminabox_host = host
  end

  def geminabox_host
    @geminabox_host ||= options[:host] || Gem.configuration.load_file(config_path)[:host]
  end

  def geminabox_host=(host)
    config = Gem.configuration.load_file(config_path).merge(:host => host)

    dirname = File.dirname(config_path)
    Dir.mkdir(dirname) unless File.exists?(dirname)

    File.open(config_path, 'w') do |f|
      f.write config.to_yaml
    end
  end

end
