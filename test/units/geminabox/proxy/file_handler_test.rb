require 'test_helper'

module Geminabox
  module Proxy
    class FileHandlerTest < Minitest::Test

      def setup
        clean_data_dir
      end

      def teardown
        Geminabox.http_adapter = HttpClientAdapter.new
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
      
      def test_remote_content
        stub_request(:get, "http://rubygems.org/foo/bar").
          to_return(:status => 200, :body => remote_content)
        assert_equal remote_content, file_handler.remote_content
      end

      def test_remote_content_with_alternative_http_adapter
        @http_dummy = HttpDummy.new
        @http_dummy.default_response = remote_content
        Geminabox.http_adapter = @http_dummy
        assert_equal remote_content, file_handler.remote_content
      end
      
      def test_remote_content_connection_failure
        stub_request(:get, "http://rubygems.org/foo/bar").
          to_return(:status => 500, :body => 'Whoops')
        assert_raises GemStoreError do 
          file_handler.remote_content
        end
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
