module Geminabox
  class CompactIndexApi

    def names
      gem_names = Set.new(all_gems.list)
      return ["---", gem_names.to_a.sort].join("\n") unless Geminabox.rubygems_proxy

      remote_names = RubygemsCompactIndexApi.fetch_names.to_s.split("\n")
      remote_names.shift if remote_names.first == "---"
      gem_names.merge(remote_names)

      ["---", gem_names.to_a.sort].join("\n")
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
      RubygemsCompactIndexApi.fetch_versions
    end

    def local_versions
      compact_indexer.fetch_versions || Server.with_rlock do
        compact_indexer.reindex(:force_rebuild)
        compact_indexer.fetch_versions
      end
    end

    def remote_gem_info(name)
      RubygemsCompactIndexApi.fetch_info(name)
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

  end
end
