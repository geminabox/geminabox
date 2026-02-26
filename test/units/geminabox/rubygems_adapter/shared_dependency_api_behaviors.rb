module Geminabox
  module RubygemsAdapter
    module SharedDependencyApiBehaviors
      def some_gem_dependencies
        [
          { 'name' => 'some_gem', 'number' => '0.0.1', 'platform' => 'ruby', 'dependencies' => [] },
          { 'name' => 'some_gem', 'number' => '0.0.2', 'platform' => 'ruby', 'dependencies' => [] },
          { 'name' => 'other_gem', 'number' => '0.0.1', 'platform' => 'ruby',
            'dependencies' => [['some_gem', ">= 0"]] }
        ]
      end

      def test_get_list_with_500_error
        stub_single_gem_request(status: 500)
        assert_raises(HTTPClient::BadResponseError) { RubygemsDependency.for(:some_gem, :other_gem) }
      end

      def test_get_list_with_401_error
        stub_single_gem_request(status: 401)
        assert_raises(HTTPClient::BadResponseError) { RubygemsDependency.for(:some_gem, :other_gem) }
      end

      def test_get_list_with_socket_error
        Geminabox.http_adapter = HttpSocketErrorDummy.new.tap { |a|
          a.default_response = 'getaddrinfo: Name or service not known'
        }
        assert_raises(SocketError) { RubygemsDependency.for(:some_gem, :other_gem) }
      end

      def test_get_list_with_500_error_and_allow_remote_failure
        stub_single_gem_request(status: 500)
        Geminabox.allow_remote_failure = true
        assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
      end

      def test_get_list_with_401_error_and_allow_remote_failure
        stub_single_gem_request(status: 401)
        Geminabox.allow_remote_failure = true
        assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
      end

      def test_get_list_with_socket_error_and_allow_remote_failure
        Geminabox.http_adapter = HttpSocketErrorDummy.new.tap { |a|
          a.default_response = 'getaddrinfo: Name or service not known'
        }
        Geminabox.allow_remote_failure = true
        assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
      end
    end
  end
end
