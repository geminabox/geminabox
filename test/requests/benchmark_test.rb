require 'test_helper'
require 'minitest/unit'
require 'rack/test'
require 'benchmark'

class BenchmarkTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    Geminabox.data = "/path/to/geminabox-data"
  end

  def app
    Geminabox::Server
  end

  test "gem badge" do
    skip "reason for benchmark test"

    gem_name = "my_awesome_tool"

    Benchmark.bm do |x|
      x.report do
        10000.times do
          get "/gems/#{gem_name}.svg"
        end
      end
    end
  end
end
