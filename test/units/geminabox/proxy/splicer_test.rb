require_relative '../../../test_helper'
module Geminabox
  module Proxy
    class SplicerTest < Minitest::Test

      def setup
        clean_data_dir
      end

      def test_make
        stub_request_for_file(file_name)
        splice = Splicer.make(file_name)
        assert_equal true, File.exist?(splice.splice_path)
      end

      def test_create
        stub_request_for_file(file_name)
        splice.create
        assert_equal true, File.exist?(splice.splice_path)
      end

      def test_spliced_file_created_from_remote
        test_create
        assert_equal(
          Marshal.load(Gem::Util.gunzip remote_content),
          Marshal.load(Gem::Util.gunzip File.binread(splice.splice_path))
        )
      end

      def test_spliced_file_created_from_merged_gzip_content_when_local_exists
        splice_with_gz
        create_local_content
        test_create
        assert_equal(
          Marshal.load(Gem::Util.gunzip merged_content),
          Marshal.load(Gem::Util.gunzip File.binread(splice.splice_path))
        )
      end

      def test_spliced_file_created_from_merged_content_when_local_exists
        create_local_content
        test_create
        assert_equal(
          local_content.to_s + remote_content.to_s,
          File.binread(splice.splice_path)
        )
      end

      # This test seems unstable, and I'm not sure why.
      def xtest_local_file_path
        expected = File.expand_path(file_name, File.join(Geminabox.data, 'proxy'))
        assert_equal expected, splice.splice_path
      end

      def test_local_file_exists_without_file
        assert_equal false, splice.local_file_exists?
      end

      def test_splice_file_exists_without_file
        assert_equal false, splice.splice_file_exists?
      end

      def test_remote_content
        stub_request_for_file(file_name)
        assert_equal remote_content, splice.remote_content
      end

      def test_gzip
        assert splice_with_gz.gzip?, "#{file_name} should be gzip"
      end

      def test_gzip_when_file_not_gz
        assert_nil splice.gzip?, "#{file_name} should not be gzip"
      end

      private
      def splice
        @splice ||= Splicer.new file_name
      end

      def splice_with_gz
        gz_file_name
        splice
      end

      def file_name
        @file_name ||= 'file_to_be_spliced'
      end

      def gz_file_name
        file_name << '.gz'
      end

      def remote_content
        @remote_content ||= Gem::Util.gzip(Marshal.dump(raw_remote_content))
      end

      def raw_remote_content
        [["remote-gem", Gem::Version.new('0.0.1'), "ruby"]]
      end

      def local_content
        @local_content ||= Gem::Util.gzip(Marshal.dump(raw_local_content))
      end

      def raw_local_content
        [["local-gem", Gem::Version.new('0.0.2'), "ruby"]]
      end

      def merged_content
        @merged_content ||= Gem::Util.gzip(Marshal.dump(raw_local_content | raw_remote_content))
      end

      def create_local_content
        File.open(splice.local_path, 'wb'){|f| f.write(local_content)}
      end

      def stub_request_for_file(file_name)
         stub_request(:get, "https://rubygems.org/#{file_name}").
          to_return(:status => 200, :body => remote_content)
      end
    end
  end
end
