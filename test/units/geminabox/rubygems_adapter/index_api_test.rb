require_relative '../../../test_helper'

module Geminabox
  module RubygemsAdapter
    class IndexApiTest < Minitest::Test
      def teardown
        Geminabox.http_adapter = HttpClientAdapter.new
        Geminabox.allow_remote_failure = false
      end

      def test_get_list
        stub_request(:get, "https://index.rubygems.org/info/some_gem")
          .to_return(:status => 200, :body => gem_info[:some_gem], :headers => { "Content-Type" => 'application/octet-stream' })
        stub_request(:get, "https://index.rubygems.org/info/other_gem")
          .to_return(:status => 200, :body => gem_info[:other_gem], :headers => { "Content-Type" => 'application/octet-stream' })

        assert_equal some_gem_dependencies, RubygemsDependency.for(:some_gem, :other_gem)
      end

      def test_get_list_with_500_error
        stub_request(:get, "https://index.rubygems.org/info/some_gem")
          .to_return(:status => 500, :body => 'Whoops')

        assert_raises HTTPClient::BadResponseError do
          RubygemsDependency.for(:some_gem, :other_gem)
        end
      end

      def test_get_list_with_401_error
        stub_request(:get, "https://index.rubygems.org/info/some_gem")
          .to_return(:status => 401, :body => 'Whoops')
        assert_raises HTTPClient::BadResponseError do
          RubygemsDependency.for(:some_gem, :other_gem)
        end
      end

      def test_get_list_with_socket_error
        http_adapter = HttpSocketErrorDummy.new
        http_adapter.default_response = 'getaddrinfo: Name or service not known'
        Geminabox.http_adapter = http_adapter
        assert_raises SocketError do
          RubygemsDependency.for(:some_gem, :other_gem)
        end
      end

      def test_get_list_with_500_error_and_allow_remote_failure
        stub_request(:get, "https://index.rubygems.org/info/some_gem")
          .to_return(:status => 500, :body => 'Whoops')

        Geminabox.allow_remote_failure = true
        assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
      end

      def test_get_list_with_401_error_and_allow_remote_failure
        stub_request(:get, "https://index.rubygems.org/info/some_gem")
          .to_return(:status => 401, :body => 'Whoops')

        Geminabox.allow_remote_failure = true
        assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
      end

      def test_get_list_with_socket_error_and_allow_remote_failure
        http_adapter = HttpSocketErrorDummy.new
        http_adapter.default_response = 'getaddrinfo: Name or service not known'
        Geminabox.http_adapter = http_adapter
        Geminabox.allow_remote_failure = true
        assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
      end

      def gem_info
        return @data if @data

        @data = {}
        @data[:some_gem] = "SOME_GEM_INFO\n" \
                           "0.0.1 | checksum:foo\n" \
                           "0.0.2 | checksum:foo"
        @data[:other_gem] = "OTHER_GEM_INFO\n" \
                            "0.0.1 some_gem:>= 0| checksum:foo"

        @data
      end

      def some_gem_dependencies
        [
          {
            'name' => 'some_gem',
            'number' => '0.0.1',
            'platform' => 'ruby',
            'dependencies' => []
          },
          {
            'name' => 'some_gem',
            'number' => '0.0.2',
            'platform' => 'ruby',
            'dependencies' => []
          },
          {
            'name' => 'other_gem',
            'number' => '0.0.1',
            'platform' => 'ruby',
            'dependencies' => [
              ['some_gem', ">= 0"]
            ]
          }
        ]
      end
    end
  end
end
