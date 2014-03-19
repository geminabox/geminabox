module Geminabox

  class Server < Sinatra::Base
    enable :static, :methodoverride

    def self.delegate_to_geminabox(*delegate_methods)
      delegate_methods.each{|m| set m, Geminabox.send(m)}
    end

    delegate_to_geminabox(
      :public_folder,
      :data,
      :build_legacy,
      :incremental_updates,
      :views,
      :allow_replace,
      :gem_permissions,
      :allow_delete,
      :rubygems_proxy
    )

    if Server.rubygems_proxy
      use Proxy::Hostess
    else
      use Hostess
    end

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
        fixup_bundler_rubygems!
        force_rebuild = true unless incremental_updates
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
        Gem::Indexer.new(data, :build_legacy => build_legacy)
      end

      def dependency_cache
        @dependency_cache ||= Geminabox::DiskCache.new(File.join(data, "_cache"))
      end
    end



    before do
      headers 'X-Powered-By' => "geminabox #{Geminabox::VERSION}"
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
      query_gems.any? ? Marshal.dump(gem_list) : 200
    end

    get '/api/v1/dependencies.json' do
      query_gems.any? ? gem_list.to_json : {}
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
      unless self.class.allow_delete?
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
      handle_incoming_gem(Geminabox::IncomingGem.new(tmpfile))
    end

    post '/api/v1/gems' do
      begin
        handle_incoming_gem(Geminabox::IncomingGem.new(request.body))
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

    def file_path
      File.expand_path(File.join(settings.data, *request.path_info))
    end

    def dependency_cache
      self.class.dependency_cache
    end

    def all_gems
      all_gems_with_duplicates.inject(:|)
    end

    def all_gems_with_duplicates
      specs_files_paths.map do |specs_file_path|
        if File.exists?(specs_file_path)
          Marshal.load(Gem.gunzip(Gem.read_binary(specs_file_path)))
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
        File.join(settings.data, spec_file_name(specs_file_type))
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
      settings.rubygems_proxy ? combined_gem_list : local_gem_list
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
      GemListMerge.from(local_gem_list, remote_gem_list)
    end

    helpers do
      def spec_for(gem_name, version, platform = default_platform)
        filename = [gem_name, version]
        filename.push(platform) if platform != default_platform
        spec_file = File.join(settings.data, "quick", "Marshal.#{Gem.marshal_version}", "#{filename.join("-")}.gemspec.rz")
        File::open(spec_file, 'r') do |unzipped_spec_file|
          unzipped_spec_file.binmode
          Marshal.load(Gem.inflate(unzipped_spec_file.read))
        end if File.exists? spec_file
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
