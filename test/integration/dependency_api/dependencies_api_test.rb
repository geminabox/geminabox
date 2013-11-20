require 'test_helper'
require 'httpclient'
require 'set'

class DependenciesApiTest < Geminabox::TestCase
  test "push a gem with dependencies" do
    cache_fixture_data_dir "a_gem_with_deps" do
      assert_can_push(:a, :deps => [[:b, '>= 0']])
    end

    deps = fetch_deps("a")
    expected = [{:name=>"a", :number=>"1.0.0", :platform=>"ruby", :dependencies=>[["b", ">= 0"]]}]
    assert_equal expected, deps
  end

  test "ask about a missing gem" do
    deps = fetch_deps("nothing", "nadda", "nought")
    assert_equal [], deps
  end

  test "get dependencies for multiple gems" do
    cache_fixture_data_dir "multiple_gems_with_deps" do
      assert_can_push(:a, :deps => [[:b, '>= 0']])
      assert_can_push(:another_gem, :deps => [[:fred, '>= 0'], [:john, '= 2.0']])
    end

    deps = fetch_deps("a", "another_gem")
    expected = Set[
      {:name=>"another_gem", :number=>"1.0.0", :platform=>"ruby", :dependencies=>[["fred", ">= 0"], ["john", "= 2.0"]]},
      {:name=>"a", :number=>"1.0.0", :platform=>"ruby", :dependencies=>[["b", ">= 0"]]}
    ]
    assert_equal expected, Set[*deps]
  end

  test "get dependencies for multiple versions of the same gem" do
    cache_fixture_data_dir "one_gem_many_versions" do
      assert_can_push(:a, :deps => [[:b, '>= 0']])
      assert_can_push(:a, :deps => [[:b, '>= 1']], :version => "2.0.0")
    end

    deps = fetch_deps("a")
    expected = [
      {:name=>"a", :number=>"1.0.0", :platform=>"ruby", :dependencies=>[["b", ">= 0"]]},
      {:name=>"a", :number=>"2.0.0", :platform=>"ruby", :dependencies=>[["b", ">= 1"]]}
    ]
    assert_equal expected, deps
  end

  test "get dependencies for a platform-dependent gem" do
    cache_fixture_data_dir "platform_dependent_gem" do
      assert_can_push(:a, :deps => [[:b, '>= 0']])
    end

    deps = fetch_deps("a")
    expected = [
      {:name=>"a", :number=>"1.0.0", :platform=>"java", :dependencies=>[["b", ">= 0"]]},
    ]
    assert_equal expected, deps
  end

  test "dependency cache is cleared as expected" do
    assert_can_push(:a, :deps => [[:b, '>= 0']])

    deps = fetch_deps("a")
    expected = [
      {:name=>"a", :number=>"1.0.0", :platform=>"ruby", :dependencies=>[["b", ">= 0"]]}
    ]
    assert_equal expected, deps

    assert_can_push(:a, :deps => [[:b, '>= 1']], :version => "2.0.0")

    deps = fetch_deps("a")
    expected = [
      {:name=>"a", :number=>"1.0.0", :platform=>"ruby", :dependencies=>[["b", ">= 0"]]},
      {:name=>"a", :number=>"2.0.0", :platform=>"ruby", :dependencies=>[["b", ">= 1"]]}
    ]
    assert_equal expected, deps
  end

  test "dependency api with empty params" do
    deps = Marshal.load HTTPClient.new.get_content(url_for("api/v1/dependencies"))
    assert_equal [], deps
  end

protected
  def fetch_deps(*gems)
    Marshal.load HTTPClient.new.get_content(url_for("api/v1/dependencies?gems=#{gems.join(",")}"))
  end
end
