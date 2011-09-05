require 'builder'
require 'sinatra'
require 'rubygems'
require 'rubygems/builder'
require "rubygems/indexer"
require 'hostess'
require 'rack-flash'
require 'shield'
require 'sinatra/sequel'
require 'sqlite3'
require 'user'

class Geminabox < Sinatra::Base
  enable :static, :methodoverride
  set :database, "sqlite://geminabox.db"

  set :public, File.join(File.dirname(__FILE__), *%w[.. public])
  set :data, File.join(File.dirname(__FILE__), *%w[.. data])
  set :views, File.join(File.dirname(__FILE__), *%w[.. views])
  set :allow_replace, false
  use Hostess
  use Rack::Session::Pool, :expire_after => 2592000
  use Rack::Flash, :accessorize => [:notice, :error]

  helpers Shield::Helpers

  class << self
    def disallow_replace?
      ! allow_replace
    end
  end

  autoload :GemVersionCollection, "geminabox/gem_version_collection"

  get '/' do
    ensure_authenticated User
    @gems = load_gems
    @index_gems = index_gems(@gems)
    erb :index
  end

  get '/login' do
    erb :login
  end

  get '/logout' do
    logout User
    redirect '/login'
  end
  
  post '/authenticate' do
    if login(User, params['user']['email'], params['user']['password'])
      redirect '/'
    else
      flash[:error] = "Invalid email or password"
      redirect '/login'
    end
  end

  get '/register' do
    erb :register
  end

  post '/do_register' do
    if params['password'] != params['password_confirmation']
      flash[:error] = "password does not match confirmation"
      status, headers, body = call env.merge("REQUEST_METHOD" => "GET", "PATH_INFO" => '/register')
      [status, headers, body.map]
    else
      user = User.new(email: params['email'], password: params['password'])
      if user.valid?
        user.save
        flash[:notice] = "Registered successfully"
      else
        flash[:error] = user.errors.full_messages.join(", ")
        status, headers, body = call env.merge("REQUEST_METHOD" => "GET", "PATH_INFO" => '/register')
        [status, headers, body.map]
      end
    end
  end

  get '/atom.xml' do
    @gems = load_gems
    erb :atom, layout: false
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


    if Geminabox.disallow_replace? and File.exist?(dest_filename)
      existing_file_digest = Digest::SHA1.file(dest_filename).hexdigest
      tmpfile_digest = Digest::SHA1.file(tmpfile.path).hexdigest

      if existing_file_digest != tmpfile_digest
        return error_response(409, "Gem already exists, you must delete the existing version first.")
      else
        return [200, "Ignoring upload, you uploaded the same thing previously."]
      end
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
