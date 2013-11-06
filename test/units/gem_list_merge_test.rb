require 'test_helper'

class GemListMergeTest < Minitest::Test

  def test_merge
    list_one = gem_list [:a], [:b]
    list_two = gem_list [:a], [:c]
    expected = gem_list [:a], [:b], [:c]
    assert_equal expected, GemListMerge.from(list_one, list_two)
  end

  def test_merge_with_different_versions
    list_one = gem_list [:a], [:b]
    list_two = gem_list [:a, '0.0.2'], [:c]
    expected = gem_list [:a], [:a, '0.0.2'], [:b], [:c]
    assert_equal expected, GemListMerge.from(list_one, list_two)
  end

  def test_merge_with_different_versions_and_duplicates
    list_one = gem_list [:a], [:b]
    list_two = gem_list [:a], [:a, '0.0.2'], [:c]
    expected = gem_list [:a], [:a, '0.0.2'], [:b], [:c]
    assert_equal expected, GemListMerge.from(list_one, list_two)
  end

  def test_merge_sorts
    list_one = gem_list [:b], [:a]
    list_two = gem_list [:c], [:a], [:a, '0.0.2']
    expected = gem_list [:a], [:a, '0.0.2'], [:b], [:c]
    assert_equal expected, GemListMerge.from(list_one, list_two)
  end

  def test_merge_with_text_keys
    list_one = gem_list [:c], [:a]
    list_two = [build_text_gem(:b)]
    expected = gem_list [:a], [:b], [:c]
    assert_equal expected, GemListMerge.from(list_one, list_two)
  end

  def test_merge_ignores_dependencies
    list_one = gem_list [:a]
    list_two = gem_list [:a]
    list_two.first[:dependencies] = [{foo: :bar}]
    expected = gem_list [:a]
    assert_equal expected, GemListMerge.from(list_one, list_two)
  end

  def test_hash
    assert_equal [:x, :y], gem_list_merge.hash.keys
    assert_equal [build_gem(:x)], gem_list_merge.hash[:x]
  end

  def build_text_gem(name, number = '0.0.1')
    {
        'name' => name.to_s,
        'number' => number,
        'platform' => 'ruby',
        'dependencies' => []
    }
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

  def gem_list_merge
    @gem_list_merge ||= GemListMerge.new(x_y_list)
  end

  def x_y_list
    @x_y_list ||= gem_list([:x], [:y])
  end


end
