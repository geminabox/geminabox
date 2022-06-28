# frozen_string_literal: true

require 'reentrant_flock'
require 'rubygems/util'
require 'set'

module Geminabox

  class Server < Sinatra::Base
    enable :static, :methodoverride
    set :public_folder, Geminabox.public_folder
    set :views, Geminabox.views

    if Geminabox.rubygems_proxy
      use Proxy::Hostess
    else
      use Hostess
    end

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

    get '/versions' do
      content_type 'text/plain'
      return halt(404) unless Geminabox.supported_compact_index_configuration?

      if Geminabox.rubygems_proxy
        GemVersionsMerge.merge(local_versions, remote_versions, strategy: Geminabox.rubygems_proxy_merge_strategy)
      else
        local_versions
      end
    end

    get '/names' do
      content_type 'text/plain'
      return halt(404) unless Geminabox.supported_compact_index_configuration?

      return ["---", load_gems.list].join("\n") unless Geminabox.rubygems_proxy

      gem_names = Set.new(load_gems.list)
      remote_names = RubygemsCompactIndexApi.fetch_names.to_s.split("\n")
      remote_names.shift if remote_names.first == "---"
      gem_names.merge(remote_names)

      ["---", gem_names.to_a.sort].join("\n")
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
        reindex(force_rebuild)
        redirect url("/")
      end
    end

    get '/info/:gemname' do
      content_type 'text/plain'
      return halt(404) unless Geminabox.supported_compact_index_configuration?

      name = params[:gemname]
      info = if Geminabox.rubygems_proxy
               if Geminabox.rubygems_proxy_merge_strategy == :local_gems_take_precedence_over_remote_gems
                 local_gem_info(name) || remote_gem_info(name)
               else
                 remote_gem_info(name) || local_gem_info(name)
               end
             else
               local_gem_info(name)
             end
      info || halt(404)
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
        File.delete file_path if File.exist? file_path
        reindex(:force_rebuild)
        redirect url("/")
      end

    end

    delete '/api/v1/gems/yank' do
      unless self.class.allow_delete?
        error_response(403, 'Gem deletion is disabled')
      end

      halt 400 unless request.form_data?

      serialize_update do
        gems = load_gems.select { |gem| request['gem_name'] == gem.name and
                                  request['version'] == gem.number.version }
        halt 404, 'Gem not found' if gems.size == 0
        gems.each do |gem|
          gem_path = File.expand_path(File.join(Geminabox.data, 'gems',
                                                "#{gem.gemfile_name}.gem"))
          load_gems.delete(gem)
          File.delete gem_path if File.exists? gem_path
        end
        reindex(:force_rebuild)
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

      begin
        serialize_update do
          handle_incoming_gem(Geminabox::IncomingGem.new(request.body))
        end
      rescue Object => o
        File.open File.join(Dir::tmpdir, "debug.txt"), "a" do |io|
          io.puts o, o.backtrace
        end
      end
    end

  private

    def reindex(force_rebuild = false)
      Indexer.new.reindex(force_rebuild)
    end

    def serialize_update(&block)
      with_rlock(&block)
    rescue ReentrantFlock::AlreadyLocked
      halt 503, { 'Retry-After' => Geminabox.retry_interval.to_s }, 'Repository lock is held by another process'
    end

    def with_rlock(&block)
      self.class.with_rlock(&block)
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

    def remote_versions
      RubygemsCompactIndexApi.fetch_versions
    end

    def local_versions
      CompactIndexer.fetch_versions || serialize_update do
        CompactIndexer.new.reindex(:force_rebuild)
        CompactIndexer.fetch_versions
      end
    end

    def remote_gem_info(name)
      RubygemsCompactIndexApi.fetch_info(name)
    end

    def local_gem_info(name)
      CompactIndexer.fetch_info(name)
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

    def file_path
      File.expand_path(File.join(Geminabox.data, *request.path_info))
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
      GemListMerge.merge(local_gem_list, remote_gem_list, strategy: Geminabox.rubygems_proxy_merge_strategy)
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

      def spec_for(gem_name, version, platform = default_platform)
        Specs.spec_for_version(GemVersion.new(gem_name, version, platform))
      end

      def default_platform
        'ruby'
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
