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
  use Hostess

  autoload :GemVersionCollection, "geminabox/gem_version_collection"

  get '/' do
    @gems, @specs = load_gems
    @index_gems = index_gems(@gems)
    erb :index
  end
  
  get '/atom.xml' do
    @gems, @specs = load_gems
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
    unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
      @error = "No file selected"
      return erb(:upload)
    end

    tmpfile.binmode

    Dir.mkdir(File.join(options.data, "gems")) unless File.directory? File.join(options.data, "gems")

    File.open(File.join(options.data, "gems", File.basename(name)), "wb") do |f|
      while blk = tmpfile.read(65536)
        f << blk
      end
    end
    reindex
    redirect "/"
  end

private
  def reindex
    Gem::Indexer.new(options.data).generate_index
  end

  def file_path
    File.expand_path(File.join(options.data, *request.path_info))
  end

  def load_gems
    gems = %w(specs prerelease_specs).inject(GemVersionCollection.new){|gems, specs_file_type|
      specs_file_path = File.join(options.data, "#{specs_file_type}.#{Gem.marshal_version}.gz")
      if File.exists?(specs_file_path)
        gems + Marshal.load(Gem.gunzip(Gem.read_binary(specs_file_path)))
      else
        gems
      end
    }

    specs = {}
    Dir.new(File.join(options.data, "quick", "Marshal.#{Gem.marshal_version}")).grep(/\.rz/).each do |spec_file|
      File.open(File.join(options.data, "quick", "Marshal.#{Gem.marshal_version}", spec_file), 'r') do |io| 
        zipped_spec = io.read 
        spec = Marshal.load(Gem.inflate(zipped_spec))
        specs[[spec.name, spec.version].join('-')] =  spec
        specs
      end
    end

    [gems, specs]
  end

  def index_gems(gems)
    Set.new(gems.map{|name, _| name[0..0]})
  end

  helpers do
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
