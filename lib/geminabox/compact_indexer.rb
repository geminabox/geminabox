require 'fileutils'

module Geminabox
  module CompactIndexer
    class << self

      def clear_index
        FileUtils.rm_rf(compact_index_path)
        FileUtils.mkdir_p(info_path)
      end

      def reindex_versions(data)
        File.binwrite(versions_path, data)
      end

      def reindex_info(name, data)
        File.binwrite(info_name_path(name), data)
      end

      def fetch_versions
        path = versions_path
        File.binread(path) if File.exist?(path)
      end

      def fetch_info(name)
        path = info_name_path(name)
        File.binread(path) if File.exist?(path)
      end

      def compact_index_path
        File.expand_path(File.join(Geminabox.data, 'compact_index'))
      end

      def versions_path
        File.join(compact_index_path, 'versions')
      end

      def info_path
        File.join(compact_index_path, 'info')
      end

      def info_name_path(name)
        File.join(info_path, name)
      end

    end
  end
end
