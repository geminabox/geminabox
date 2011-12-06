require 'uri'
require 'yaml'

class Gem::Commands::InaboxCommand < Gem::Command
  def description
    'Push a gem up to your GemInABox'
  end

  def arguments
    "GEM       built gem to push up"
  end

  def usage
    "#{program_name} GEM"
  end

  def initialize
    super 'inabox', description
      
    load_config

    add_option('-c', '--configure', "Configure GemInABox") do |value, options|
      options[:configure] = true
    end

    add_option('-g', '--host HOST', "Host to upload to.") do |value, options|
      options[:host] = value
    end
      
    add_option('-t', '--trust-certificates', "Trust SSL certificates") do |value, options|
      options[:'trust-certificates'] = true
    end
  end

  def execute
    return configure if options[:configure]
    setup
    send_gem
  end

  def setup
    if options[:args].size == 0
      @gemfiles = [find_gem]
    else
      @gemfiles = get_all_gem_names
    end
    configure unless geminabox_host
  end

  def find_gem
    say "You didn't specify a gem, looking for one in pkg..."
    path, directory = File.split(Dir.pwd)
    possible_gems = Dir.glob("pkg/#{directory}-*.gem")
    raise Gem::CommandLineError, "Couldn't find a gem in pkg, please specify a gem name on the command line (e.g. gem inabox GEMNAME)" unless possible_gems.any?
    name_regexp = Regexp.new("^pkg/#{directory}-")
    possible_gems.sort_by{ |a| Gem::Version.new(a.sub(name_regexp,'')) }.last
  end

  def send_gem
    # sanitize printed URL if a password is present
    
    ssl = geminabox_host.start_with? "https"
    
    url = URI.parse(geminabox_host)
    url_for_presentation = url.clone
    url_for_presentation.password = '***' if url_for_presentation.password

    @gemfiles.each do |gemfile|
      say "Pushing #{File.basename(gemfile)} to #{url_for_presentation}..."

      File.open(gemfile, "rb") do |file|
        request_body, request_headers = Multipart::MultipartPost.new.prepare_query("file" => file)

        con = create_connection url
          
        if ssl then
            con.use_ssl = true
            
            if geminabox_trust then
                con.verify_mode = OpenSSL::SSL::VERIFY_NONE
            end
        end
        
        con.start { |local_con|
          req = Net::HTTP::Post.new('/upload', request_headers)
          req.basic_auth(url.user, url.password) if url.user
          handle_response(local_con.request(req, request_body))
        }
      end
    end
  end

    
  def create_connection con_uri
    require 'net/https'

    if proxy_info = ENV['http_proxy'] || ENV['HTTP_PROXY'] and uri = URI.parse(proxy_info)
      Net::HTTP::Proxy(uri.host, uri.port, uri.user, uri.password).new(con_uri.host, con_uri.port)
    else
      Net::HTTP.new(con_uri.host, con_uri.port)
    end
  end

  def handle_response(response)
    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts response.body
    else
      response.error!
    end
  end

  def config_path
    File.join(Gem.user_home, '.gem', 'geminabox')
  end

  def configure
    say "Enter the root url for your personal geminabox instance. (E.g. http://gems/)"
    host = ask("Host:")
    self.geminabox_host = host
    self.geminabox_trust = ask_yes_no("Would you like to trust certificates?")
    save_config
  end

  def geminabox_host
    options[:host] || @config[:host]
  end

  def geminabox_host=(host)
    @config = @config.merge(:host => host)
  end

  def geminabox_trust
    options[:'trust-certificates'] || @config[:'trust-certificates']
  end
      
  def geminabox_trust=(trust)
    @config = @config.merge(:'trust-certificates' => trust)
  end
      
  def load_config
      @config = {}
      @config = Gem.configuration.load_file(config_path) if File.exists?(config_path)
      
      dirname = File.dirname(config_path)
      Dir.mkdir(dirname) unless File.exists?(dirname)
  end
      
  def save_config
      File.open(config_path, 'w') do |f|
          f.write @config.to_yaml
      end
  end
      
  module Multipart
    require 'net/http'
    require 'cgi'

    class Param
      attr_accessor :k, :v
      def initialize( k, v )
        @k = k
        @v = v
      end

      def to_multipart
        return "Content-Disposition: form-data; name=\"#{k}\"\r\n\r\n#{v}\r\n"
      end
    end

    class FileParam
      attr_accessor :k, :filename, :content
      def initialize( k, filename, content )
        @k = k
        @filename = filename
        @content = content
      end

      def to_multipart
        return "Content-Disposition: form-data; name=\"#{k}\"; filename=\"#{filename}\"\r\n" + "Content-Transfer-Encoding: binary\r\n" + "Content-Type: application/octet-stream\r\n\r\n" + content + "\r\n"
      end
    end

    class MultipartPost
      BOUNDARY = 'tarsiers-rule0000'
      HEADER = {"Content-type" => "multipart/form-data, boundary=" + BOUNDARY + " "}

      def prepare_query(params)
        fp = []
        params.each {|k,v|
          if v.respond_to?(:read)
            fp.push(FileParam.new(k, v.path, v.read))
          else
            fp.push(Param.new(k,v))
          end
        }
        query = fp.collect {|p| "--" + BOUNDARY + "\r\n" + p.to_multipart }.join("") + "--" + BOUNDARY + "--"
        return query, HEADER
      end
    end
  end
end
