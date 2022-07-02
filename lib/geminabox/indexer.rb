# frozen_string_literal: true

require 'geminabox'
require 'rubygems/indexer'
require 'fileutils'

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

    def initialize(datadir)
      @indexer = Gem::Indexer.new(datadir, :build_legacy => Geminabox.build_legacy)
      @compact_indexer = CompactIndexer.new(datadir)
    end

    attr_reader :indexer, :compact_indexer

    def load_index(path)
      Marshal.load(File.binread(path))
    end

    def reindex(force_rebuild = nil)
      self.class.fixup_bundler_rubygems!
      force_rebuild = true unless Geminabox.incremental_updates
      if force_rebuild
        full_reindex
      else
        incremental_reindex
      end
    end

    def yank(file_path)
      return reindex(:force_rebuild) unless Geminabox.incremental_updates

      spec = indexer.map_gems_to_specs([file_path]).first
      version = GemVersion.from_spec(spec)
      spec_file = Specs.spec_file_name_for_version(version)
      File.delete(file_path)
      FileUtils.rm_f(spec_file)
      Server.dependency_cache.flush_key(spec.name)

      all_versions = load_index(indexer.dest_specs_index)

      all_versions_by_name = all_versions.group_by(&:first)
      remove_spec_from_versions(spec, all_versions_by_name[spec.name])

      all_versions = all_versions_by_name.values.flatten(1).sort
      latest_versions = all_versions_by_name.values.map(&:last).compact.sort

      if spec.version.prerelease?
        prerelease_versions = load_index(indexer.dest_prerelease_specs_index)
        remove_spec_from_versions(spec, prerelease_versions)
      end

      update_indexes(all_versions, latest_versions, prerelease_versions)

      compact_indexer.yank(spec)
    end

    private

    def full_reindex
      indexer.generate_index
      Server.dependency_cache.flush
      compact_indexer.reindex
    end

    def incremental_reindex
      updated_gemspecs = self.class.updated_gemspecs(indexer)
      return if updated_gemspecs.empty?

      indexer.update_index
      updated_gemspecs.each do |spec|
        Server.dependency_cache.flush_key(spec.name)
      end
      compact_indexer.reindex(updated_gemspecs)
    rescue Errno::ENOENT
      full_reindex
    rescue StandardError => e
      $stderr.puts "#{e.class}:#{e.message}\n#{e.backtrace.join("\n")}"
      full_reindex
    end

    def remove_spec_from_versions(spec, versions)
      return unless versions

      versions.reject! { |n, v, p| n == spec.name && v == spec.version && p == spec.platform }
    end

    def update_indexes(all_versions, latest_versions, prerelease_versions = nil)
      FileUtils.mkdir_p(indexer.directory)
      updated_files = []
      updated_files += update_index(indexer.dest_specs_index, all_versions)
      updated_files += update_index(indexer.dest_latest_specs_index, latest_versions)
      updated_files += update_index(indexer.dest_prerelease_specs_index, prerelease_versions) if prerelease_versions

      updated_files.each do |path|
        FileUtils.mv(path, indexer.dest_directory)
      end
    ensure
      FileUtils.rm_r(indexer.directory)
    end

    def update_index(dest_path, versions)
      new_index_path = File.join(indexer.directory, File.basename(dest_path))
      compacted_versions = indexer.compact_specs(versions)
      File.binwrite(new_index_path, Marshal.dump(compacted_versions))
      indexer.gzip(new_index_path)
      [new_index_path, "#{new_index_path}.gz"]
    end

  end
end
