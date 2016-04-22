require 'test_helper'
require 'minitest/mock'

module Geminabox
  module Proxy
    class CopierTest < Minitest::Test

      def setup
        clean_data_dir
      end

      def test_remote_content_failure
        raise_stub = proc { puts caller.join("\n") ; raise }
        copier.stub :remote_content, raise_stub do
          begin
            copier.get_remote
          rescue
          end
          assert(!File.exists?(copier.proxy_path), "Cached file should not exist")
        end
      end

      def test_with_no_files_in_place
        assert_equal false, copier.local_file_exists?
        assert_equal false, copier.proxy_file_exists?
      end

      def test_with_local_in_place
        create_local
        assert_equal true, copier.local_file_exists?
        assert_equal false, copier.proxy_file_exists?
      end

      def test_with_proxy_in_place
        create_proxy
        assert_equal false, copier.local_file_exists?
        assert_equal true, copier.proxy_file_exists?
      end

      def test_copy_from_local
        create_local
        Copier.copy(test_file)
        assert_proxy_file_present
        assert_equal local_content, proxy_file_content
      end

      def test_copy_with_proxy_and_local
        create_local
        create_proxy
        Copier.copy(test_file)
        assert_equal proxy_content, proxy_file_content
      end

      def test_copy_with_just_proxy
        create_proxy
        Copier.copy(test_file)
        assert_equal proxy_content, proxy_file_content
      end

      def test_copy_with_neither_local_nor_proxy
        create_remote
        Copier.copy(test_file)
        assert_proxy_file_present
        assert_equal remote_content, proxy_file_content
      end

      def test_copy_with_sub_directory
        @test_file = 'sub_directory/co-pier_test.txt'
        test_with_local_in_place
      end

      private
      def copier
        @copier ||= Copier.new(test_file)
      end

      def create_local_file
        File.open(file_path(locator.local_path), 'w'){|f| f.write(new_content)}
      end

      def file_path(path)
        File.expand_path(test_file, path)
      end

      def test_file
        @test_file ||= 'copier_test.txt'
      end

      def locator
        @locator ||= FileHandler.new test_file
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

      def create_local
        locator.local_path
        File.open(locator.local_path, 'w+'){|f| f.write(local_content)}
      end

      def create_proxy
        File.open(locator.proxy_path, 'w+'){|f| f.write(proxy_content)}
      end

      def create_remote
        stub_request_for_remote
      end

      def stub_request_for_remote
         stub_request(:get, "http://rubygems.org/#{test_file}").
          to_return(:status => 200, :body => remote_content)
      end

      def proxy_file_content
        File.read(locator.proxy_path)
      end

      def assert_proxy_file_present
        assert copier.proxy_file_exists?, "#{locator.proxy_folder_name}/#{test_file} should be present"
      end

    end
  end
end
