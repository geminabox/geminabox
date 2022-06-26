# frozen_string_literal: true

require 'reentrant_flock'
require 'rubygems/util'

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

      def fixup_bundler_rubygems!
        return if @post_reset_hook_applied
        Gem.post_reset{ Gem::Specification.all = nil } if defined? Bundler and Gem.respond_to? :post_reset
        @post_reset_hook_applied = true
      end

      def reindex(force_rebuild = false)
        fixup_bundler_rubygems!
        force_rebuild = true unless Geminabox.incremental_updates
        if force_rebuild
          indexer.generate_index
          dependency_cache.flush
        else
          begin
            require 'geminabox/indexer'
            updated_gemspecs = Geminabox::Indexer.updated_gemspecs(indexer)
            return if updated_gemspecs.empty?
            indexer.update_index
            updated_gemspecs.each { |gem| dependency_cache.flush_key(gem.name) }
          rescue Errno::ENOENT
            with_rlock { reindex(:force_rebuild) }
          rescue => e
            puts "#{e.class}:#{e.message}"
            puts e.backtrace.join("\n")
            with_rlock { reindex(:force_rebuild) }
          end
        end
      rescue Gem::SystemExitException
      end

      def indexer
        Gem::Indexer.new(Geminabox.data, :build_legacy => Geminabox.build_legacy)
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

      return halt(404) if Geminabox.rubygems_proxy_merge_strategy == :combine_local_and_remote_gem_versions || !Geminabox.index_format
      if Geminabox.rubygems_proxy
        GemVersionsMerge.merge(local_versions, remote_versions, strategy: Geminabox.rubygems_proxy_merge_strategy)
      else
        local_versions
      end
    end

    get '/names' do
      content_type 'text/plain'

      return halt(404) if Geminabox.rubygems_proxy_merge_strategy == :combine_local_and_remote_gem_versions || !Geminabox.index_format
      if Geminabox.rubygems_proxy
        error_response(404, 'Not implemented')
      else
        ["---", load_gems.list].join("\n")
      end
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
        self.class.reindex(force_rebuild)
        reindex_compact_cache
        redirect url("/")
      end
    end

    get '/info/:gemname' do
      content_type 'text/plain'

      return halt(404) if Geminabox.rubygems_proxy_merge_strategy == :combine_local_and_remote_gem_versions || !Geminabox.index_format
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
        self.class.reindex(:force_rebuild)
        reindex_compact_cache
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
          File.delete gem_path if File.exists? gem_path
        end
        self.class.reindex(:force_rebuild)
        reindex_compact_cache
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
        reindex_compact_cache
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

    def reindex_compact_cache
      return unless Geminabox.index_format
      CompactIndexer.clear_index
      CompactIndexer.reindex_versions(versions_template)
      Hash[load_gems.by_name].each do |name, versions|
        CompactIndexer.reindex_info(name, info_template(versions))
      end
    rescue SystemCallError => e
      puts "Compact index error #{e.message}\n"
    end

    def remote_versions
      RubygemsVersions.fetch
    end

    def local_versions
      CompactIndexer.fetch_versions || versions_template
    end

    def remote_gem_info(name)
      RubygemsInfo.fetch(name)
    end

    def local_gem_info(name)
      gem = find_gem(name)
      CompactIndexer.fetch_info(name) || info_template(gem) if gem
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

    def all_gems
      all_gems_with_duplicates.inject(:|)
    end

    def all_gems_with_duplicates
      specs_files_paths.map do |specs_file_path|
        if File.exist?(specs_file_path)
          Marshal.load(Gem::Util.gunzip(Gem.read_binary(specs_file_path)))
        else
          []
        end
      end
    end

    def specs_file_types
      [:specs, :prerelease_specs]
    end

    def specs_files_paths
      specs_file_types.map do |specs_file_type|
        File.join(Geminabox.data, spec_file_name(specs_file_type))
      end
    end

    def spec_file_name(specs_file_type)
      [specs_file_type, Gem.marshal_version, 'gz'].join('.')
    end

    def load_gems
      @loaded_gems ||= Geminabox::GemVersionCollection.new(all_gems)
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

    def platform_name(_gem_name, version, platform)
      name = version.to_s
      name << "-#{platform}" if platform != default_platform
      name
    end

    def gem_platform_name(gem_name, version, platform)
      "#{gem_name}-#{platform_name(gem_name, version, platform)}"
    end

    def checksum_for(gem_name, version, platform = default_platform)
      filename = gem_platform_name(gem_name, version, platform)
      filename = "#{filename}.gem"
      file = File.join(Geminabox.data, "gems", filename)
      Digest::SHA256.file(file).hexdigest if File.exist? file
    end

    def info_template(gem)
      str = "---\n".dup
      gem.by_name do |name, versions|
        versions.each do |version|
          str << version_info(name, version)
          str << "\n"
        end
      end
      str
    end

    def versions_template
      str = "created_at: #{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%L%z')}\n".dup
      str << "---\n"
      gems = load_gems
      lookup = Hash[gems.by_name]
      gems.by_name do |name, versions|
        str << "#{name} "
        str << versions.map{ |version| platform_name(name, version.number, version.platform) }.join(",")
        str << " "
        str << Digest::MD5.hexdigest(info_template(lookup[name]))
        str << "\n"
      end
      str
    end

    def version_info(name, version)
      platform = version.platform || default_platform
      spec = spec_for(name, version.number, platform)
      "#{platform_name(name, version.number, platform)} #{dependencies_for(name, version.number, spec, platform)} " \
        "|checksum:#{checksum_for(name, version.number, platform)}" \
        "#{ruby_requirements_for(name, version.number, spec, platform)}#{rubygems_requirements_for(name, version.number, spec, platform)}"
    end

    def ruby_requirements_for(_gem_name, _version, spec, _platform = default_platform)
      required_ruby_version = spec.required_ruby_version
      ",ruby:#{required_ruby_version.requirements.sort.map{|requirement|
 requirement.join(" ")}.join("&")}" unless required_ruby_version <=> without_ruby_requirement
    end

    def rubygems_requirements_for(_gem_name, _version, spec, _platform = default_platform)
      required_rubygems_version = spec.required_rubygems_version
      ",rubygems:#{required_rubygems_version.requirements.sort.map{|requirement|
 requirement.join(" ")}.join("&")}" unless required_rubygems_version <=> without_ruby_requirement
    end

    def dependencies_for(_gem_name, _version, spec, _platform = default_platform)
      spec.runtime_dependencies.sort.map { |dependency| [dependency.name, dependency.requirement.requirements.sort.map{ |requirement|
 requirement.join(" ")}.join("&")].join(":") }.join(",")
    end

    def without_ruby_requirement
      @without_ruby_requirement ||= Gem::Requirement.new([">= 0"])
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
        filename = gem_platform_name(gem_name, version, platform)
        spec_file = File.join(Geminabox.data, "quick", "Marshal.#{Gem.marshal_version}", "#{filename}.gemspec.rz")
        File::open(spec_file, 'r') do |unzipped_spec_file|
          unzipped_spec_file.binmode
          Marshal.load(Gem::Util.inflate(unzipped_spec_file.read))
        end if File.exist? spec_file
      end

      def default_platform
        'ruby'
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
          map    { |dep| name_and_requirements_for(dep) }
      end

      def name_and_requirements_for(dep)
        name = dep.name.kind_of?(Array) ? dep.name.first : dep.name
        [name, dep.requirement.to_s]
      end
    end
  end

end
