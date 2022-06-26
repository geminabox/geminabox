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

    def initialize
      @indexer = Gem::Indexer.new(Geminabox.data, :build_legacy => Geminabox.build_legacy)
    end

    attr_reader :indexer

    def reindex(force_rebuild = nil)
      self.class.fixup_bundler_rubygems!
      force_rebuild = true unless Geminabox.incremental_updates
      if force_rebuild
        indexer.generate_index
        Server.dependency_cache.flush
        CompactIndexer.new.reindex
      else
        begin
          updated_gemspecs = self.class.updated_gemspecs(indexer)
          return if updated_gemspecs.empty?

          indexer.update_index
          updated_gemspecs.each do |spec|
            Server.dependency_cache.flush_key(spec.name)
          end
          CompactIndexer.new.reindex(updated_gemspecs)
        rescue Errno::ENOENT
          Server.with_rlock { reindex(:force_rebuild) }
        rescue StandardError => e
          puts "#{e.class}:#{e.message}"
          puts e.backtrace.join("\n")
          Server.with_rlock { reindex(:force_rebuild) }
        end
      end
    end
  end
end
