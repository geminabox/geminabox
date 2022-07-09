module Geminabox
  class CompactIndexApi

    include Gem::UserInteraction

    attr_reader :cache

    def initialize
      @cache = RemoteCache.new
      @api = RubygemsCompactIndexApi.new
    end

    def names
      local_gem_list = Set.new(all_gems.list)
      return format_gem_names(local_gem_list) unless Geminabox.rubygems_proxy

      remote_name_data = remote_names
      return format_gem_names(local_gem_list) unless remote_name_data

      remote_gem_list = remote_name_data.split("\n")[1..-1]
      format_gem_names(local_gem_list.merge(remote_gem_list))
    end

    def local_names
      format_gem_names(Set.new(all_gems.list))
    end

    def remote_names
      fetch("names") do |etag|
        @api.fetch_names(etag)
      end
    end

    def versions
      return local_versions unless Geminabox.rubygems_proxy

      GemVersionsMerge.merge(local_versions, remote_versions)
    end

    def info(name)
      if Geminabox.rubygems_proxy
        local_gem_info(name) || remote_gem_info(name)
      else
        local_gem_info(name)
      end
    end

    def remote_versions
      fetch("versions") do |etag|
        @api.fetch_versions(etag)
      end
    end

    def local_versions
      compact_indexer.fetch_versions || Server.with_rlock do
        compact_indexer.reindex(:force_rebuild)
        compact_indexer.fetch_versions
      end
    end

    def remote_gem_info(name)
      fetch("info/#{name}") do |etag|
        @api.fetch_info(name, etag)
      end
    end

    def local_gem_info(name)
      compact_indexer.fetch_info(name)
    end

    def all_gems
      Geminabox::GemVersionCollection.new(Specs.all_gems)
    end

    def compact_indexer
      @compact_indexer ||= CompactIndexer.new(Geminabox.data)
    end

    def determine_proxy_status(verbose = nil)
      names_to_set(local_names).select do |name|
        status, conflicts = proxy_status(name)
        extra = ": #{conflicts.join(', ')}" if conflicts
        say "#{name}: #{status}#{extra}" if verbose
        status == :proxied
      end
    end

    def remove_proxied_gems_from_local_index
      proxied = determine_proxy_status
      proxied_versions = all_gems.by_name.to_h.select do |name, _|
        proxied.include?(name)
      end

      gem_count = proxied_versions.values.map(&:size).inject(0, :+)
      say "Moving #{gem_count} proxied gem versions to proxy cache"

      proxied_versions.each do |_name, versions|
        versions.each do |version|
          move_gem_to_proxy_cache("#{version.gemfile_name}.gem")
        end
      end

      say "Rebuilding all indexes"
      Indexer.new(Geminabox.data).reindex(:force_rebuild)
    end

    def move_gems_from_proxy_cache_to_local_index
      gems_to_move = Dir["#{cache.gems_dir}/*.gem"]
      gem_count = gems_to_move.size
      say "Moving #{gem_count} proxied gem versions to local index"
      FileUtils.mv(gems_to_move, File.join(Geminabox.data, "gems"))
      say "Rebuilding all indexes"
      Indexer.new(Geminabox.data).reindex(:force_rebuild)
    end

    private

    def move_gem_to_proxy_cache(gemfile)
      gemfile_path = File.join(Geminabox.data, "gems", gemfile)
      cache_path = cache.cache_path.join("gems", gemfile)
      move_gem(gemfile_path, cache_path)
    end

    def move_gem(gemfile_path, cache_path)
      FileUtils.mv(gemfile_path, cache_path)
    rescue Errno::ENOENT
      say "gem file #{gemfile_path} could not be moved to proxy cache as it's gone"
    end

    def names_to_set(raw_names)
      Set.new(raw_names.split("\n")[1..-1])
    end

    def proxy_status(name)
      local_info = DependencyInfo.new(name)
      local_info.content = local_gem_info(name)
      remote_info = DependencyInfo.new(name)
      remote_info.content = remote_gem_info(name)
      if remote_info.empty?
        [:local, nil]
      elsif local_info.subsumed_by?(remote_info)
        [:proxied, nil]
      elsif local_info.disjoint?(remote_info)
        [:disjoint, local_info.version_names]
      else
        [:conflicts, local_info.conflicts(remote_info)]
      end
    end

    def format_gem_names(gem_list)
      ["---", gem_list.to_a.sort, ""].join("\n")
    end

    def fetch(path, &block)
      etag = cache.md5(path)
      code, data = block.call(etag)
      if code == 200
        cache.store(path, data)
      else # 304, 503, etc...
        cache.read(path)
      end
    end

  end
end
