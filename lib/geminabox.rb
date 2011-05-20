require "builder"
require 'sinatra/base'
require 'rubygems'
require 'rubygems/builder'
require "rubygems/indexer"

require 'hostess'


class Geminabox < Sinatra::Base
  enable :static, :methodoverride

  set :public, File.join(File.dirname(__FILE__), *%w[.. public])
  set :data, File.join(File.dirname(__FILE__), *%w[.. data])
  set :views, File.join(File.dirname(__FILE__), *%w[.. views])
  set :disallow_replace, false
  use Hostess

  class << self
    alias :disallow_replace :disallow_replace?
  end

  autoload :GemVersionCollection, "geminabox/gem_version_collection"

  get '/' do
    @gems = load_gems
    @index_gems = index_gems(@gems)
    erb :index
  end

  get '/atom.xml' do
    @gems = load_gems
    erb :atom, :layout => false
  end

  get '/upload' do
    erb :upload
  end

  delete '/gems/*.gem' do
    File.delete file_path if File.exists? file_path
    reindex
    redirect "/"
  end

  post '/upload' do
    return "Please ensure #{File.expand_path(Geminabox.data)} is writable by the geminabox web server." unless File.writable? Geminabox.data
    unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
      @error = "No file selected"
      return erb(:upload)
    end

    tmpfile.binmode

    Dir.mkdir(File.join(options.data, "gems")) unless File.directory? File.join(options.data, "gems")

    dest_filename = File.join(options.data, "gems", File.basename(name))

    if Geminabox.disallow_replace? && File.exist?(dest_filename)
      return error_response(409, "Gem already exists")
    end

    File.open(dest_filename, "wb") do |f|
      while blk = tmpfile.read(65536)
        f << blk
      end
    end
    reindex
    redirect "/"
  end

private

  def error_response(code, message)
    html = <<HTML
<html>
  <head><title>Error - #{code}</title></head>
  <body>
    <h1>Error - #{code}</h1>
    <p>#{message}</p>
  </body>
</html>
HTML
    [code, html]
  end

  def reindex
    Gem::Indexer.new(options.data).generate_index
  end

  def file_path
    File.expand_path(File.join(options.data, *request.path_info))
  end

  def load_gems
    %w(specs prerelease_specs).inject(GemVersionCollection.new){|gems, specs_file_type|
      specs_file_path = File.join(options.data, "#{specs_file_type}.#{Gem.marshal_version}.gz")
      if File.exists?(specs_file_path)
        gems + Marshal.load(Gem.gunzip(Gem.read_binary(specs_file_path)))
      else
        gems
      end
    }
  end

  def index_gems(gems)
    Set.new(gems.map{|name, _| name[0..0]})
  end

  helpers do
    def spec_for(gem_name, version)
      spec_file = File.join(options.data, "quick", "Marshal.#{Gem.marshal_version}", "#{gem_name}-#{version}.gemspec.rz")
      Marshal.load(Gem.inflate(File.read(spec_file))) if File.exists? spec_file
    end

    def url_for(path)
      url = request.scheme + "://"
      url << request.host

      if request.scheme == "https" && request.port != 443 ||
          request.scheme == "http" && request.port != 80
        url << ":#{request.port}"
      end

      url << path
    end
  end
end
