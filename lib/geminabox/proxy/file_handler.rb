
module Geminabox
  module Proxy
    class FileHandler

      attr_reader :file_name

      def initialize(file_name)
        @file_name = file_name
        ensure_destination_exists
      end
      
      def local_path
        File.expand_path(file_name, root_path)
      end

      def root_path
        Geminabox.data
      end

      def local_file_exists?
        file_exists? local_path
      end
      
      def proxy_file_exists?
        file_exists? proxy_path
      end

      def proxy_path
        File.expand_path(file_name, proxy_folder_path)
      end

      def file_exists?(path)
        File.exists? path
      end

      def proxy_folder_path
        File.join(root_path, proxy_folder_name)
      end

      def proxy_folder_name
        'proxy'
      end

      def remote_content
        Geminabox.http_adapter.get_content(remote_url).force_encoding(encoding)
      rescue
        raise GemStoreError.new(500, "Unable to get content from #{remote_url}")
      end

      def remote_url
        "http://rubygems.org/#{file_name}"
      end

      def local_content
        File.read(local_path).force_encoding(encoding)
      end

      private
      def encoding
        "UTF-8"
      end

      def ensure_destination_exists
        create_local_folder unless local_folder_exists?
        create_proxy_folder unless proxy_folder_exists?
      end

      def proxy_file_folder
        File.dirname proxy_path
      end

      def proxy_folder_exists?
        Dir.exists?(proxy_file_folder)
      end

      def create_proxy_folder
        FileUtils.mkdir_p(proxy_file_folder)
      end

      def local_file_folder
        File.dirname local_path
      end

      def local_folder_exists?
        Dir.exists?(local_file_folder)
      end

      def create_local_folder
        FileUtils.mkdir_p(local_file_folder)
      end

    end
  end
end
