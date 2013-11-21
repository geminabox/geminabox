require 'test_helper'

module Geminabox
  module Proxy
    class FileHandlerTest < Minitest::Test

      def setup
        clean_data_dir
      end

      def test_with_no_files_in_place
        assert_equal false, file_handler.local_file_exists?
        assert_equal false, file_handler.proxy_file_exists?
      end

      def test_with_local_in_place
        create_local
        assert_equal true, file_handler.local_file_exists?
        assert_equal false, file_handler.proxy_file_exists?
      end

      def test_with_proxy_in_place
        create_proxy
        assert_equal false, file_handler.local_file_exists?
        assert_equal true, file_handler.proxy_file_exists?
      end

      private
      def file_handler
        @file_handler ||= FileHandler.new 'foo/bar'
      end

      def create_local
        file_handler.local_path
        File.open(file_handler.local_path, 'w+'){|f| f.write(local_content)}
      end

      def create_proxy
        File.open(file_handler.proxy_path, 'w+'){|f| f.write(proxy_content)}
      end

      def local_content
        @local_content ||= this_is_a :local
      end

      def proxy_content
        @proxy_content ||= this_is_a :proxy
      end

      def remote_content
        @remote_content ||= this_is_a :remote
      end

      def this_is_a(type)
        "This is a #{type} file"
      end

    end
  end
end
