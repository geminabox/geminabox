require_relative '../../test_helper'
module Geminabox
  class GemStoreTest < Minitest::Test

    def setup
      clean_data_dir
    end

    def test_prepare_data_folders_with_data_as_file
      Geminabox.data = File.join(__FILE__)
      gem_store = GemStore.new(gem_file(:example))
      assert_gem_store_error(500, 'is a directory') do
        gem_store.prepare_data_folders
      end
    end

    def test_prepare_data_folders_with_data_as_unwriteable_folder
      Geminabox.data = '/'
      gem_store = GemStore.new(gem_file(:example))
      assert_gem_store_error(500, 'is writable') do
        gem_store.prepare_data_folders
      end
    end

    def test_prepare_data_folders
      empty_folder = File.expand_path('empty', Geminabox.data)
      FileUtils.mkdir_p(empty_folder)
      Geminabox.data = empty_folder
      gem_store = GemStore.new(gem_file(:example))
      assert_equal(false, File.directory?(File.expand_path('gems', empty_folder)))
      gem_store.prepare_data_folders
      assert_equal(true, File.directory?(File.expand_path('gems', empty_folder)))
    end

    def test_ensure_gem_valid
      invalid_gem = Geminabox::IncomingGem.new(StringIO.new('NOT A GEM'))
      gem_file = GemStore.new invalid_gem
      assert_gem_store_error(400, 'Cannot process gem') do
        gem_file.ensure_gem_valid
      end
    end

    private
    def assert_gem_store_error(code, message, &block)
      assert_raises GemStoreError do
        block.call
      end
      begin
        block.call
      rescue GemStoreError => error
        assert_equal(code, error.code)
        assert_match(message, error.reason)
      end
    end

    def gem_file(*args)
      GemFactory.gem_file(*args)
    end
  end
end
