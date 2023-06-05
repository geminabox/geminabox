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

      GemVersionsMerge.new(local_versions, remote_versions).call
    end

    def info(name)
      if Geminabox.rubygems_proxy
        (
          local_gem_info(name)&.lines.to_a +
          remote_gem_info(name)&.lines.to_a
        ).compact.sort.uniq.join
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
      compact_indexer.fetch_versions
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
      @compact_indexer ||= CompactIndexer.new
    end

    def determine_proxy_status(verbose = nil)
      remote_version_info = VersionInfo.new
      remote_version_info.content = remote_versions

      local_gem_names = names_to_set(local_names).to_a
      status_and_conflicts = Parallel.map(local_gem_names, in_threads: 10) do |name|
        [name, *proxy_status(name, remote_version_info)]
      end

      report_proxy_status(status_and_conflicts) if verbose

      status_and_conflicts.map { |name, status, _| name if status == :proxied }.compact
    end

    def report_proxy_status(status_and_conflicts)
      status_and_conflicts.sort_by(&:first).each do |name, status, conflicts|
        extra = ": #{conflicts.join(', ')}" if conflicts
        say "#{name}: #{status}#{extra}"
      end
    end

    def remove_proxied_gems_from_local_index
      proxied = determine_proxy_status
      proxied_versions = all_gems.by_name.to_h.select do |name, _|
        proxied.include?(name)
      end

      gem_count = proxied_versions.values.map(&:size).inject(0, :+)
      say "Moving #{gem_count} proxied gem versions to proxy cache"

      proxied_versions.each_value do |versions|
        versions.each do |version|
          move_gem_to_proxy_cache("#{version.gemfile_name}.gem")
        end
      end

      say "Rebuilding all indexes"
      Indexer.new.reindex(:force_rebuild)
    end

    def move_gems_from_proxy_cache_to_local_index
      gems_to_move = Dir["#{cache.gems_dir}/*.gem"]
      gem_count = gems_to_move.size

      say "Moving #{gem_count} proxied gem versions to local index"
      FileUtils.mv(gems_to_move, File.join(Geminabox.data, "gems"))

      say "Rebuilding all indexes"
      Indexer.new.reindex(:force_rebuild)
    end

    private

    def move_gem_to_proxy_cache(gemfile)
      gemfile_path = File.join(Geminabox.data, "gems", gemfile)
      cache_path = cache.cache_path.join("gems", gemfile)
      FileUtils.mv(gemfile_path, cache_path)
    end

    def names_to_set(raw_names)
      Set.new(raw_names.split("\n")[1..-1])
    end

    def proxy_status(name, remote_version_info)
      local_info = DependencyInfo.new(name)
      local_info.content = local_gem_info(name)

      remote_info_digest = remote_version_info.digests[name]
      return [:local, nil] unless remote_info_digest

      remote_info = remote_info_for_gem(name, remote_info_digest)

      proxy_status_from_local_and_remote_info(local_info, remote_info)
    end

    def remote_info_for_gem(name, remote_info_digest)
      cached_remote_info_up_to_date = cache.md5("info/#{name}") == remote_info_digest
      remote_data = cached_remote_info_up_to_date ? cache.read("info/#{name}") : remote_gem_info(name)

      DependencyInfo.new(name).tap do |remote_info|
        remote_info.content = remote_data
      end
    end

    def proxy_status_from_local_and_remote_info(local_info, remote_info)
      if local_info.subsumed_by?(remote_info)
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

    def fetch(path)
      etag = cache.md5(path)
      code, data = yield etag
      if code == 200
        cache.store(path, data)
      else # 304, 503, etc...
        cache.read(path)
      end
    end

  end
end
