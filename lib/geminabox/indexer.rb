# frozen_string_literal: true

require 'geminabox'
require 'rubygems/indexer'

module Geminabox
  class Indexer

    class << self

      def updated_gemspecs(indexer)
        specs_mtime = File.stat(indexer.dest_specs_index).mtime rescue Time.at(0)

        updated_gems = indexer.gem_file_list.select do |gem|
          gem_mtime = File.stat(gem).mtime
          gem_mtime >= specs_mtime
        end

        indexer.map_gems_to_specs updated_gems
      end

      def fixup_bundler_rubygems!
        return if @post_reset_hook_applied

        Gem.post_reset { Gem::Specification.all = nil } if defined?(Bundler) && Gem.respond_to?(:post_reset)
        @post_reset_hook_applied = true
      end

    end

    def indexer
      @indexer ||= Gem::Indexer.new(Geminabox.data, :build_legacy => Geminabox.build_legacy)
    end

    def reindex(force_rebuild)
      self.class.fixup_bundler_rubygems!
      force_rebuild = true unless Geminabox.incremental_updates
      if force_rebuild
        indexer.generate_index
        Server.dependency_cache.flush
        reindex_compact_cache
      else
        begin
          updated_gemspecs = self.class.updated_gemspecs(indexer)
          return if updated_gemspecs.empty?

          indexer.update_index
          updated_gemspecs.each do |spec|
            Server.dependency_cache.flush_key(spec.name)
          end
          reindex_compact_cache(updated_gemspecs)
        rescue Errno::ENOENT
          Server.with_rlock { reindex(:force_rebuild) }
        rescue StandardError => e
          puts "#{e.class}:#{e.message}"
          puts e.backtrace.join("\n")
          Server.with_rlock { reindex(:force_rebuild) }
        end
      end
    end

    def log_time(text)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
    ensure
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      printf("%s: %.2f seconds\n", text, end_time - start_time)
    end

    def incremental_reindex_compact_cache(gem_specs)
      version_info = VersionInfo.new
      version_info.load_versions

      gem_specs.group_by(&:name).each do |name, specs|
        info = DependencyInfo.new(name)
        data = CompactIndexer.fetch_info(name)
        info.content = data if data
        specs.each do |spec|
          gem_version = GemVersion.new(name, spec.version, spec.platform)
          checksum = Specs.checksum_for_version(gem_version)
          info.add_gem_spec_and_gem_checksum(spec, checksum)
        end
        CompactIndexer.reindex_info(name, info.content)
        version_info.update_gem_versions(info)
      end

      version_info.write
    end

    def all_specs
      Geminabox::GemVersionCollection.new(Specs.all_gems)
    end

    def full_reindex_compact_cache
      CompactIndexer.clear_index
      version_info = VersionInfo.new

      all_specs.by_name.to_h.each do |name, versions|
        info = info_template(versions)
        CompactIndexer.reindex_info(name, info.content)
        version_info.update_gem_versions(info)
      end

      version_info.write
    end

    def reindex_compact_cache(specs = nil)
      return unless Geminabox.index_format

      if specs && File.exist?(CompactIndexer.versions_path)
        log_time("compact index incremental reindex") do
          incremental_reindex_compact_cache(specs)
        end
        return
      end

      log_time("compact index full rebuild") do
        full_reindex_compact_cache
      end
    rescue SystemCallError => e
      CompactIndexer.clear_index
      puts "Compact index error #{e.message}\n"
    end

    def info_template(gem)
      DependencyInfo.new(gem.first.name) do |info|
        gem.by_name do |_name, versions|
          versions.each do |version|
            spec = Specs.spec_for_version(version)
            next unless spec

            checksum = Specs.checksum_for_version(version)
            next unless checksum

            info.add_gem_spec_and_gem_checksum(spec, checksum)
          end
        end
      end
    end

  end
end
