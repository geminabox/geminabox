# frozen_string_literal: true

require 'reentrant_flock'
require 'rubygems/util'
require 'set'

module Geminabox

  class Server < Sinatra::Base
    enable :static, :methodoverride
    set :public_folder, Geminabox.public_folder
    set :views, Geminabox.views

    include Hostess

    class << self
      def disallow_replace?
        ! Geminabox.allow_replace
      end

      def allow_delete?
        Geminabox.allow_delete
      end

      def allow_upload?
        Geminabox.allow_upload
      end

      def dependency_cache
        @dependency_cache ||= Geminabox::DiskCache.new(File.join(Geminabox.data, "_cache"))
      end

      def with_rlock(&block)
        file_class.open(Geminabox.lockfile, File::RDWR | File::CREAT) do |f|
          ReentrantFlock.synchronize(f, File::LOCK_EX | File::LOCK_NB, &block)
        end
      end

      # This method provides a test hook, as stubbing File is painful...
      def file_class
        @file_class ||= File
      end

      def file_class=(klass)
        @file_class = klass
      end
    end


    before do
      headers 'X-Powered-By' => "geminabox #{Geminabox::VERSION}"
    end

    get '/' do
      @gems = load_gems
      @index_gems = index_gems(@gems)
      @allow_upload = self.class.allow_upload?
      @allow_delete = self.class.allow_delete?
      erb :index
    end

    get '/atom.xml' do
      @gems = load_gems
      erb :atom, :layout => false
    end

    get '/api/v1/dependencies' do
      query_gems.any? ? Marshal.dump(gem_list) : 200
    end

    get '/api/v1/dependencies.json' do
      query_gems.any? ? gem_list.to_json : {}
    end

    get '/names' do
      content_type 'text/plain'
      with_etag_for(CompactIndexApi.new.names)
    end

    get '/versions' do
      content_type 'text/plain'
      with_etag_for(CompactIndexApi.new.versions)
    end

    get '/info/:gemname' do
      content_type 'text/plain'
      with_etag_for(CompactIndexApi.new.info(params[:gemname]))
    end

    get '/upload' do
      unless self.class.allow_upload?
        error_response(403, 'Gem uploading is disabled')
      end

      erb :upload
    end

    get '/reindex' do
      serialize_update do
        params[:force_rebuild] ||= 'true'
        unless %w(true false).include? params[:force_rebuild]
          error_response(400, "force_rebuild parameter must be either of true or false")
        end
        force_rebuild = params[:force_rebuild] == 'true'
        indexer.reindex(force_rebuild)
        redirect url("/")
      end
    end

    get '/gems/:gemname' do
      @gem = find_gem(params[:gemname])
      @allow_delete = self.class.allow_delete?
      halt 404 unless @gem
      erb :gem
    end

    delete '/gems/*.gem' do
      unless self.class.allow_delete?
        error_response(403, 'Gem deletion is disabled - see https://github.com/geminabox/geminabox/issues/115')
      end

      serialize_update do
        file_path = File.expand_path(File.join(Geminabox.data, *request.path_info))
        halt 404, 'Gem not found' unless File.exist?(file_path)

        indexer.yank(file_path)
        redirect url("/")
      end

    end

    delete '/api/v1/gems/yank' do
      unless self.class.allow_delete?
        error_response(403, 'Gem deletion is disabled')
      end

      halt 400 unless request.form_data?

      serialize_update do
        name, version = request.values_at('gem_name', 'version')
        file_path = File.expand_path(File.join(Geminabox.data, 'gems', "#{name}-#{version}.gem"))
        halt 404, 'Gem not found' unless File.exist? file_path

        indexer.yank(file_path)
        return 200, 'Yanked gem and reindexed'
      end
    end

    post '/upload' do
      unless self.class.allow_upload?
        error_response(403, 'Gem uploading is disabled')
      end

      if params[:file] && params[:file][:filename] && (tmpfile = params[:file][:tempfile])
        serialize_update do
          handle_incoming_gem(Geminabox::IncomingGem.new(tmpfile))
        end
      else
        @error = "No file selected"
        halt [400, erb(:upload)]
      end
    end

    post '/api/v1/gems' do
      unless self.class.allow_upload?
        error_response(403, 'Gem uploading is disabled')
      end

      serialize_update do
        handle_incoming_gem(Geminabox::IncomingGem.new(request.body))
      end
    end

    private

    def indexer
      @indexer ||= Indexer.new
    end

    def with_etag_for(content)
      halt 404 unless content

      etag = %("#{Digest::MD5.hexdigest(content)}")
      halt 304 if request.env['HTTP_IF_NONE_MATCH'] == etag

      headers['Etag'] = etag
      content
    end

    def serialize_update(&block)
      with_retry do
        with_rlock(&block)
      end
    end

    def with_rlock(&block)
      self.class.with_rlock(&block)
    end

    def with_retry
      yield
    rescue ReentrantFlock::AlreadyLocked
      halt 503, { 'Retry-After' => Geminabox.retry_interval.to_s }, 'Repository lock is held by another process'
    end

    def handle_incoming_gem(gem)
      begin
        GemStore.create(gem, params[:overwrite])
      rescue GemStoreError => error
        error_response error.code, error.reason
      end

      begin
        Geminabox.on_gem_received.call(gem) if Geminabox.on_gem_received
      rescue
        # ignore errors which occur within the hook
      end

      if api_request?
        "Gem #{gem.name} received and indexed."
      else
        redirect url("/")
      end
    end

    def find_gem(name)
      Hash[load_gems.by_name][name]
    end

    def api_request?
      request.accept.first.to_s != "text/html"
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

    def dependency_cache
      self.class.dependency_cache
    end

    def load_gems
      @loaded_gems ||= Geminabox::GemVersionCollection.new(Specs.all_gems)
    end

    def index_gems(gems)
      Set.new(gems.map{|gem| gem.name[0..0].downcase})
    end

    def gem_list
      Geminabox.rubygems_proxy ? combined_gem_list : local_gem_list
    end

    def query_gems
      params[:gems].to_s.split(',')
    end

    def local_gem_list
      query_gems.map{|query_gem| gem_dependencies(query_gem) }.flatten(1)
    end

    def remote_gem_list
      RubygemsDependency.for(*query_gems)
    end

    def combined_gem_list
      GemListMerge.merge(local_gem_list, remote_gem_list)
    end

    helpers do
      def href(text)
        if text && (text.start_with?('http://') || text.start_with?('https://'))
          Rack::Utils.escape_html(text)
        else
          '#'
        end
      end

      def h(text)
        Rack::Utils.escape_html(text)
      end

      def spec_for(gem_name, version, platform)
        Specs.spec_for_version(GemVersion.new(gem_name, version, platform))
      end

      # Return a list of versions of gem 'gem_name' with the dependencies of each version.
      def gem_dependencies(gem_name)
        dependency_cache.marshal_cache(gem_name) do
          load_gems.
            select { |gem| gem_name == gem.name }.
            map    { |gem| [gem, Specs.spec_for_version(gem)] }.
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
          map    { |dep| name_and_requirements_for(dep) }
      end

      def name_and_requirements_for(dep)
        name = dep.name.kind_of?(Array) ? dep.name.first : dep.name
        [name, dep.requirement.to_s]
      end
    end
  end

end
