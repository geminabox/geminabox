require_relative '../../test_helper'

module Geminabox
  class GemListMergeTest < Minitest::Test

    def test_merge
      list_one = gem_list [:a], [:b]
      list_two = gem_list [:a], [:c]
      expected = gem_list [:a], [:b], [:c]
      assert_equal expected, GemListMerge.merge(list_one, list_two, strategy: :combine_local_and_remote_gem_versions)
    end

    def test_merge_with_different_versions
      list_one = gem_list [:a], [:b]
      list_two = gem_list [:a, '0.0.2'], [:c]
      expected = gem_list [:a], [:a, '0.0.2'], [:b], [:c]
      assert_equal expected, GemListMerge.merge(list_one, list_two, strategy: :combine_local_and_remote_gem_versions)
    end

    def test_merge_with_different_versions_and_duplicates
      list_one = gem_list [:a], [:b]
      list_two = gem_list [:a], [:a, '0.0.2'], [:c]
      expected = gem_list [:a], [:a, '0.0.2'], [:b], [:c]
      assert_equal expected, GemListMerge.merge(list_one, list_two, strategy: :combine_local_and_remote_gem_versions)
    end

    def test_merge_sorts
      list_one = gem_list [:b], [:a]
      list_two = gem_list [:c], [:a], [:a, '0.0.2']
      expected = gem_list [:a], [:a, '0.0.2'], [:b], [:c]
      assert_equal expected, GemListMerge.merge(list_one, list_two, strategy: :combine_local_and_remote_gem_versions)
    end

    def test_merge_ignores_dependencies
      list_one = gem_list [:a]
      list_two = gem_list [:a]
      list_two.first[:dependencies] = [{foo: :bar}]
      expected = gem_list [:a]
      assert_equal expected, GemListMerge.merge(list_one, list_two, strategy: :combine_local_and_remote_gem_versions)
    end

    def test_merge_with_empty_list
      list_one = gem_list [:a], [:b]
      list_two = []
      expected = gem_list [:a], [:b]
      assert_equal expected, GemListMerge.merge(list_one, list_two, strategy: :combine_local_and_remote_gem_versions)
    end

    def test_local_gems_take_precedence_over_remote_gems_merge_strategy
      list_one = gem_list [:b], [:a]
      list_two = gem_list [:c], [:a], [:a, '0.0.2']
      expected = gem_list [:b], [:a], [:c]
      assert_equal expected, GemListMerge.merge(list_one, list_two, strategy: :local_gems_take_precedence_over_remote_gems)
    end

    def build_gem(name, number = '0.0.1')
      {
          name: name.to_s,
          number: number,
          platform: 'ruby',
          dependencies: []
      }
    end

    def gem_list(*conf)
      conf.map{|args| build_gem(*args)}
    end

  end
end
