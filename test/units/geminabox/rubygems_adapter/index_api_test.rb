require_relative '../../../test_helper'
require_relative 'shared_dependency_api_behaviors'

module Geminabox
  module RubygemsAdapter
    class IndexApiTest < Minitest::Test
      include SharedDependencyApiBehaviors

      def teardown
        Geminabox.http_adapter = HttpClientAdapter.new
        Geminabox.allow_remote_failure = false
      end

      def stub_single_gem_request(status:)
        stub_request(:get, "https://index.rubygems.org/info/some_gem")
          .to_return(status: status, body: 'Whoops')
      end

      def test_get_list
        stub_request(:get, "https://index.rubygems.org/info/some_gem")
          .to_return(status: 200, body: gem_info[:some_gem],
                     headers: { "Content-Type" => 'application/octet-stream' })
        stub_request(:get, "https://index.rubygems.org/info/other_gem")
          .to_return(status: 200, body: gem_info[:other_gem],
                     headers: { "Content-Type" => 'application/octet-stream' })

        assert_equal some_gem_dependencies, RubygemsDependency.for(:some_gem, :other_gem)
      end

      def gem_info
        @data ||= {
          some_gem: "SOME_GEM_INFO\n" \
                    "0.0.1 | checksum:foo\n" \
                    "0.0.2 | checksum:foo",
          other_gem: "OTHER_GEM_INFO\n" \
                     "0.0.1 some_gem:>= 0| checksum:foo"
        }
      end
    end
  end
end
