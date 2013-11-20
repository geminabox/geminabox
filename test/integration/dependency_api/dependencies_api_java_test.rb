require 'test_helper'
require 'httpclient'
require 'set'

class DependenciesApiJavaTest < Geminabox::TestCase
  test "push a java gem with dependencies" do
    cache_fixture_data_dir "a_java_gem_with_deps" do
      assert_can_push(:a_java,
                      :deps => [[:b, '>= 0']],
                      :platform => "java")
    end

    deps = fetch_deps("a_java")
    expected = [{:name => "a_java",
                 :number => "1.0.0",
                 :platform => "java",
                 :dependencies => [["b", ">= 0"]]}]
    assert_equal expected,
    deps
  end

  test "get dependencies for multiple java gems" do
    cache_fixture_data_dir "multiple_java_gems_with_deps" do
      assert_can_push(:a_java,
                      :deps => [[:b, '>= 0']],
                      :platform => "java")
      assert_can_push(:another_java_gem,
                      :deps => [[:fred, '>= 0'],
                                [:john, '= 2.0']],
                      :platform => "java")
    end

    deps = fetch_deps("a_java",
                      "another_java_gem")
    expected = Set[{:name => "another_java_gem",
                    :number => "1.0.0",
                    :platform => "java",
                    :dependencies => [["fred", ">= 0"],
                                    ["john", "= 2.0"]]},
                   {:name => "a_java",
                    :number => "1.0.0",
                    :platform => "java",
                    :dependencies => [["b", ">= 0"]]}]
    assert_equal expected, Set[*deps]
  end

  test "get dependencies for multiple versions of the same java gem" do
    cache_fixture_data_dir "one_java_gem_many_versions" do
      assert_can_push(:a_java,
                      :deps => [[:b, '>= 0']],
                      :platform => "java")
      assert_can_push(:a_java,
                      :deps => [[:b, '>= 1']],
                      :version => "2.0.0",
                      :platform => "java")
    end

    deps = fetch_deps("a_java")
    expected = [{:name => "a_java",
                 :number => "1.0.0",
                 :platform => "java",
                 :dependencies => [["b", ">= 0"]]},
                {:name => "a_java",
                 :number => "2.0.0",
                 :platform => "java",
                 :dependencies => [["b", ">= 1"]]}]
    assert_equal expected, deps
  end

  test "dependency cache is cleared as expected" do
    assert_can_push(:a_java,
                    :deps => [[:b, '>= 0']],
                    :platform => "java")

    deps = fetch_deps("a_java")
    expected = [{:name => "a_java",
                 :number => "1.0.0",
                 :platform => "java",
                 :dependencies => [["b", ">= 0"]]}]
    assert_equal expected, deps

    assert_can_push(:a_java,
                    :deps => [[:b, '>= 1']],
                    :version => "2.0.0",
                    :platform => "java")

    deps = fetch_deps("a_java")
    expected = [{:name => "a_java",
                 :number => "1.0.0",
                 :platform => "java",
                 :dependencies => [["b", ">= 0"]]},
                {:name => "a_java",
                 :number => "2.0.0",
                 :platform => "java",
                 :dependencies => [["b", ">= 1"]]}]
    assert_equal expected, deps
  end

  protected
  def fetch_deps(*gems)
    Marshal.load HTTPClient.new.get_content(url_for("api/v1/dependencies?gems=#{gems.join(",")}"))
  end
end
