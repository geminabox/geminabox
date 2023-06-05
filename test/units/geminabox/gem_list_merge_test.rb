require_relative '../../test_helper'

module Geminabox
  class GemListMergeTest < Minitest::Test

    def test_merge
      list_one = gem_list [:b], [:a]
      list_two = gem_list [:c], [:a], [:a, '0.0.2']
      expected = gem_list [:b], [:a], [:c]
      assert_equal expected, GemListMerge.merge(list_one, list_two)
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
