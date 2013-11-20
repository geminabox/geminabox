require 'rubygems'
require 'digest/md5'
require 'builder'
require 'sinatra/base'
require 'rubygems/indexer'
require 'rubygems/package'
require 'hostess'
require 'geminabox/version'
require 'geminabox/gem_store'
require 'geminabox/gem_store_error'
require 'rss/atom'
require 'tempfile'

class Geminabox < Sinatra::Base
  enable :static, :methodoverride

  set :public_folder, File.join(File.dirname(__FILE__), *%w[.. public])
  set :data, File.join(File.dirname(__FILE__), *%w[.. data])
  set :build_legacy, false
  set :incremental_updates, true
  set :views, File.join(File.dirname(__FILE__), *%w[.. views])
  set :allow_replace, false
  set :gem_permissions, 0644
  set :allow_delete, true
  use Hostess

  class << self
    def disallow_replace?
      ! allow_replace
    end

    def allow_delete?
      allow_delete
    end

    def fixup_bundler_rubygems!
      return if @post_reset_hook_applied
      Gem.post_reset{ Gem::Specification.all = nil } if defined? Bundler and Gem.respond_to? :post_reset
      @post_reset_hook_applied = true
    end

    def reindex(force_rebuild = false)
      Geminabox.fixup_bundler_rubygems!
      force_rebuild = true unless Geminabox.incremental_updates
      if force_rebuild
        indexer.generate_index
        dependency_cache.flush
      else
        begin
          require 'geminabox/indexer'
          updated_gemspecs = Geminabox::Indexer.updated_gemspecs(indexer)
          Geminabox::Indexer.patch_rubygems_update_index_pre_1_8_25(indexer)
          indexer.update_index
          updated_gemspecs.each { |gem| dependency_cache.flush_key(gem.name) }
        rescue => e
          puts "#{e.class}:#{e.message}"
          puts e.backtrace.join("\n")
          reindex(:force_rebuild)
        end
      end
    end

    def indexer
      Gem::Indexer.new(Geminabox.data, :build_legacy => Geminabox.build_legacy)
    end

    def dependency_cache
      @dependency_cache ||= Geminabox::DiskCache.new(File.join(Geminabox.data, "_cache"))
    end
  end

  autoload :GemVersionCollection, "geminabox/gem_version_collection"
  autoload :GemVersion, "geminabox/gem_version"
  autoload :DiskCache, "geminabox/disk_cache"
  autoload :IncomingGem, "geminabox/incoming_gem"

  before do
    headers 'X-Powered-By' => "geminabox #{GeminaboxVersion}"
  end

  get '/' do
    @gems = load_gems
    @index_gems = index_gems(@gems)
    erb :index
  end

  get '/atom.xml' do
    @gems = load_gems
    erb :atom, :layout => false
  end

  get '/api/v1/dependencies' do
    query_gems = params[:gems].to_s.split(',')
    deps = query_gems.inject([]){|memo, query_gem| memo + gem_dependencies(query_gem) }
    Marshal.dump(deps)
  end

  get '/upload' do
    erb :upload
  end

  get '/reindex' do
    self.class.reindex(:force_rebuild)
    redirect url("/")
  end

  get '/gems/:gemname' do
    gems = Hash[load_gems.by_name]
    @gem = gems[params[:gemname]]
    halt 404 unless @gem
    erb :gem
  end

  delete '/gems/*.gem' do
    unless Geminabox.allow_delete?
      error_response(403, 'Gem deletion is disabled - see https://github.com/cwninja/geminabox/issues/115')
    end
    File.delete file_path if File.exists? file_path
    self.class.reindex(:force_rebuild)
    redirect url("/")
  end

  post '/upload' do
    unless params[:file] && params[:file][:filename] && (tmpfile = params[:file][:tempfile])
      @error = "No file selected"
      halt [400, erb(:upload)]
    end
    handle_incoming_gem(IncomingGem.new(tmpfile))
  end

  post '/api/v1/gems' do
    begin
      handle_incoming_gem(IncomingGem.new(request.body))
    rescue Object => o
      File.open "/tmp/debug.txt", "a" do |io|
        io.puts o, o.backtrace
      end
    end
  end

private

  def handle_incoming_gem(gem)
    begin
      GemStore.create(gem, params[:overwrite])
    rescue GemStoreError => error
      error_response error.code, error.reason
    end

    if api_request?
      "Gem #{gem.name} received and indexed."
    else
      redirect url("/")
    end
  end

  def api_request?
    request.accept.first != "text/html"
  end

  def error_response(code, message)
    halt [code, message] if api_request?
    html = <<HTML
<html>
  <head><title>Error - #{code}</title></head>
  <body>
    <h1>Error - #{code}</h1>
    <p>#{message}</p>
  </body>
</html>
HTML
    halt [code, html]
  end

  def indexer
    Gem::Indexer.new(settings.data, :build_legacy => settings.build_legacy)
  end

  def file_path
    File.expand_path(File.join(settings.data, *request.path_info))
  end

  def dependency_cache
    @dependency_cache ||= Geminabox::DiskCache.new(File.join(settings.data, "_cache"))
  end

  def all_gems
    %w(specs prerelease_specs).map{ |specs_file_type|
      specs_file_path = File.join(settings.data, "#{specs_file_type}.#{Gem.marshal_version}.gz")
      if File.exists?(specs_file_path)
        Marshal.load(Gem.gunzip(Gem.read_binary(specs_file_path)))
      else
        []
      end
    }.inject(:|)
  end

  def load_gems
    @loaded_gems ||= Geminabox::GemVersionCollection.new(all_gems)
  end

  def index_gems(gems)
    Set.new(gems.map{|gem| gem.name[0..0].downcase})
  end

  helpers do
    def spec_for(gem_name, version, platform='ruby')
      version = "#{version}-#{platform}" if platform != 'ruby'
      spec_file = File.join(settings.data, "quick", "Marshal.#{Gem.marshal_version}", "#{gem_name}-#{version}.gemspec.rz")
      Marshal.load(Gem.inflate(File.read(spec_file))) if File.exists? spec_file
    end

    # Return a list of versions of gem 'gem_name' with the dependencies of each version.
    def gem_dependencies(gem_name)
      dependency_cache.marshal_cache(gem_name) do
        load_gems.
          select { |gem| gem_name == gem.name }.
          map    { |gem| [gem, spec_for(gem.name, gem.number, gem.platform)] }.
          reject { |(_, spec)| spec.nil? }.
          map do |(gem, spec)|
            {
              :name => gem.name,
              :number => gem.number.version,
              :platform => gem.platform,
              :dependencies => runtime_dependencies(spec)
            }
          end
      end
    end

    def runtime_dependencies(spec)
      spec.
        dependencies.
        select { |dep| dep.type == :runtime }.
        map    { |dep| [dep.name, dep.requirement.to_s] }
    end
  end
end
