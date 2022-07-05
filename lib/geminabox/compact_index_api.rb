module Geminabox
  class CompactIndexApi

    attr_reader :cache

    def initialize
      @cache = RemoteCache.new
      @api = RubygemsCompactIndexApi.new
    end

    def names
      local_gem_list = Set.new(all_gems.list)
      return format_gem_names(local_gem_list) unless Geminabox.rubygems_proxy

      remote_names = fetch("names") do |etag|
        @api.fetch_names(etag)
      end
      return format_gem_names(local_gem_list) unless remote_names

      remote_gem_list = remote_names.split("\n")[1..-1]
      format_gem_names(local_gem_list.merge(remote_gem_list))
    end

    def versions
      return local_versions unless Geminabox.rubygems_proxy

      GemVersionsMerge.merge(local_versions, remote_versions, strategy: Geminabox.rubygems_proxy_merge_strategy)
    end

    def info(name)
      if !Geminabox.rubygems_proxy
        local_gem_info(name)
      elsif Geminabox.rubygems_proxy_merge_strategy == :local_gems_take_precedence_over_remote_gems
        local_gem_info(name) || remote_gem_info(name)
      else
        remote_gem_info(name) || local_gem_info(name)
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

    private

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
