require_relative '../../../test_helper'
require_relative 'shared_dependency_api_behaviors'

module Geminabox
  module RubygemsAdapter
    class DependencyApiTest < Minitest::Test
      include SharedDependencyApiBehaviors

      def setup
        Geminabox.rubygems_adapter = :dependency_api
      end

      def teardown
        Geminabox.rubygems_adapter = :index
        Geminabox.http_adapter = HttpClientAdapter.new
        Geminabox.allow_remote_failure = false
      end

      def stub_single_gem_request(status:)
        stub_request(:get, "https://bundler.rubygems.org/api/v1/dependencies?gems=some_gem,other_gem")
          .to_return(status: status, body: 'Whoops')
      end

      def test_get_list
        stub_request(:get, "https://bundler.rubygems.org/api/v1/dependencies?gems=some_gem,other_gem")
          .to_return(status: 200, body: Marshal.dump(some_gem_dependencies),
                     headers: { "Content-Type" => 'application/octet-stream' })

        assert_equal some_gem_dependencies, RubygemsDependency.for(:some_gem, :other_gem)
      end
    end
  end
end
