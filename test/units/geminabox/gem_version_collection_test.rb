require_relative '../../test_helper'
module Geminabox
  class GemVersionCollectionTest < Minitest::Test
    GIB = Geminabox
    def test_it_coerces_things_to_gem_versions
      expected = GIB::GemVersion.new('foo', '1.2.3', 'ruby')
      actual = GIB::GemVersionCollection.new([['foo', '1.2.3', 'ruby']]).oldest

      assert_equal expected, actual
    end

    def test_it_groups_by_name
      subject = GIB::GemVersionCollection.new([
        ['foo', '1.2.3', 'ruby'],
        ['foo', '1.2.4', 'ruby'],
        ['bar', '1.2.4', 'ruby'],
        ['foo', '1.2.4', 'x86_amd64-linux'],
      ])

      actual = Hash[subject.by_name]
      assert_equal GIB::GemVersionCollection, actual['foo'].class
      assert_equal 3, actual['foo'].size
      assert_equal 1, actual['bar'].size
    end

    def test_it_should_be_sorted_by_version
      subject = GIB::GemVersionCollection.new([
        ['foo', '1.2.3', 'ruby'],
        ['foo', '1.2.4', 'ruby'],
        ['foo', '1.0.4', 'ruby']
      ])

      assert_equal '1.0.4', subject.oldest.version.to_s
      assert_equal '1.2.4', subject.newest.version.to_s
    end

    def test_it_should_be_sorted_by_name_first
      subject = GIB::GemVersionCollection.new([
        ['bbb', '1.2.3', 'ruby'],
        ['aaa', '1.2.4', 'ruby'],
        ['bbb', '1.0.4', 'ruby']
      ])

      assert_equal 'bbb', subject.oldest.name
      assert_equal 'aaa', subject.newest.name
    end

    def test_from_specs_index_loads_release_and_prerelease_specs
      clean_data_dir
      inject_gems do |builder|
        builder.gem "alpha"
        builder.gem "alpha", version: "2.0.0.pre"
        builder.gem "beta", platform: "java"
      end

      collection = Geminabox::GemVersionCollection.from_specs_index(Geminabox.data)
      assert_equal [["alpha", "1.0.0"], ["alpha", "2.0.0.pre"], ["beta", "1.0.0"]],
                   collection.map { |gem| [gem.name, gem.number.to_s] }.sort
    end

    def test_from_specs_index_returns_an_empty_collection_when_no_index_exists
      clean_data_dir
      collection = Geminabox::GemVersionCollection.from_specs_index(Geminabox.data)
      assert_equal 0, collection.size
    end
  end
end
