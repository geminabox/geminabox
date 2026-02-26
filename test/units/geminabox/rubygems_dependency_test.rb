require_relative '../../test_helper'

module Geminabox
  class RubygemsDependencyTest < Minitest::Test
    def setup
      Geminabox.allow_remote_failure = true
    end

    def teardown
      Geminabox.rubygems_adapter = :index
      Geminabox.allow_remote_failure = false
    end

    def test_for_index
      stub_request(:get, "https://index.rubygems.org/info/some_gem").
        to_return(:status => 500, :body => 'Whoops')

      Geminabox.rubygems_adapter = :index
      assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
    end

    def test_for_index_api
      stub_request(:get, "https://index.rubygems.org/info/some_gem").
        to_return(:status => 500, :body => 'Whoops')

      Geminabox.rubygems_adapter = :index_api
      assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
    end

    def test_for_dependency
      stub_request(:get, "https://bundler.rubygems.org/api/v1/dependencies?gems=some_gem,other_gem").
        to_return(:status => 500, :body => 'Whoops')

      Geminabox.rubygems_adapter = :dependency
      assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
    end

    def test_for_dependency_api
      stub_request(:get, "https://bundler.rubygems.org/api/v1/dependencies?gems=some_gem,other_gem").
        to_return(:status => 500, :body => 'Whoops')

      Geminabox.rubygems_adapter = :dependency_api
      assert_equal [], RubygemsDependency.for(:some_gem, :other_gem)
    end
  end
end
