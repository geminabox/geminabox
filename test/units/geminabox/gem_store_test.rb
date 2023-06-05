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
      refute File.directory?(File.expand_path('gems', empty_folder))
      gem_store.prepare_data_folders
      assert File.directory?(File.expand_path('gems', empty_folder))
    end

    def test_ensure_gem_valid
      invalid_gem = Geminabox::IncomingGem.new(StringIO.new('NOT A GEM'))
      gem_file = GemStore.new invalid_gem
      assert_gem_store_error(400, 'Cannot process gem') do
        gem_file.ensure_gem_valid
      end
    end

    def test_uploads_of_identical_gems_are_ignored
      gem = incoming_gem(:example, version: "1.0.0")
      GemStore.create(gem)
      gem = incoming_gem(:example, version: "1.0.0")
      assert_gem_store_error(200, "Ignoring upload") do
        GemStore.create(gem)
      end
    end

    def test_upload_of_an_updated_gem_is_rejected
      gem = incoming_gem(:example, version: "1.0.0")
      GemStore.create(gem)
      GemFactory.delete("example-1.0.0.gem")
      gem = incoming_gem(:example, version: "1.0.0", deps: { "rake" => [">= 10"] })
      assert_gem_store_error(409, "not permitted") do
        GemStore.create(gem)
      end
    end

    def test_uploading_two_versions_of_a_new_local_gem
      Geminabox.rubygems_proxy = true
      stub_request(:get, "https://bundler.rubygems.org/info/example")
        .with(headers: { 'User-Agent' => /./ })
        .to_return(status: 404, body: "", headers: {})
      gem1 = incoming_gem(:example, version: "1.0.0")
      GemStore.create(gem1)
      assert File.exist?(File.join(Geminabox.data, "gems", "example-1.0.0.gem"))
      gem2 = incoming_gem(:example, version: "2.0.0")
      GemStore.create(gem2)
      assert File.exist?(File.join(Geminabox.data, "gems", "example-2.0.0.gem"))
    ensure
      Geminabox.rubygems_proxy = false
    end

    def test_uploading_a_version_of_gem_unknown_to_rubygems
      Geminabox.rubygems_proxy = true
      stub_request(:get, "https://bundler.rubygems.org/info/example")
        .with(headers: { 'User-Agent' => /./ })
        .to_return(status: 200, body: "---\n1.0.0 |checksum:unknown", headers: {})
      gem = incoming_gem(:example, version: "3.0.0")
      GemStore.create(gem)
      assert File.exist?(File.join(Geminabox.data, "gems", "example-3.0.0.gem"))
    ensure
      Geminabox.rubygems_proxy = false
    end

    def test_uploading_a_version_of_a_gem_already_known_to_rubygems
      Geminabox.rubygems_proxy = true
      gem_file_path = gem_file(:example, version: "4.0.0")
      checksum = Digest::SHA256.file(gem_file_path).hexdigest
      gem = IncomingGem.new(File.open(gem_file_path, "rb"))
      stub_request(:get, "https://bundler.rubygems.org/info/example")
        .with(headers: { 'User-Agent' => /./ })
        .to_return(status: 200, body: "---\n4.0.0 |checksum:#{checksum}", headers: {})
      assert_gem_store_error(412, 'Ignoring upload') do
        GemStore.create(gem)
      end
      refute File.exist?(File.join(Geminabox.data, "gems", "example-4.0.0.gem"))
    ensure
      Geminabox.rubygems_proxy = false
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

    def incoming_gem(*args)
      IncomingGem.new(File.open(gem_file(*args), "rb"))
    end
  end
end
