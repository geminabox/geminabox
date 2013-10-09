require 'test_helper'
require 'json'

class RubyGemDependencyTest < Minitest::Test
  def test_get_list
    stub_request(:get, "https://bundler.rubygems.org/api/v1/dependencies.json?gems=some_gem,other_gem").
      to_return(:status => 200, :body => some_gem_dependencies.to_json, :headers => {}, :content_type => 'application/json')

    assert_equal some_gem_dependencies, RubygemsDependency.for(:some_gem, :other_gem)
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
