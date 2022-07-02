require "simplecov"
SimpleCov.start

require "rubygems"
gem "bundler"
require "bundler/setup"

require_relative '../lib/geminabox'
require 'minitest/autorun'
require 'fileutils'
require_relative 'test_support/gem_factory'
require_relative 'test_support/geminabox_test_case'
require_relative 'test_support/http_dummy'
require_relative 'test_support/http_socket_error_dummy'

require 'capybara/mechanize'
require 'capybara/dsl'

require 'minitest/reporters'
if ENV['MINITEST_REPORTER']
  Minitest::Reporters.use!
else
  Minitest::Reporters.use!([Minitest::Reporters::DefaultReporter.new])
end

require 'webmock/minitest'
WebMock.disable_net_connect!(:allow_localhost => true)

Capybara.default_driver = :mechanize
Capybara.app_host = "http://localhost"
module TestMethodMagic
  def test(test_name, &block)
    define_method "test_method: #{test_name} ", &block
  end
end

class Minitest::Test
  extend TestMethodMagic

  TEST_DATA_DIR=File.join(Dir.tmpdir, "geminabox-test-data")
  def clean_data_dir
    FileUtils.rm_rf(TEST_DATA_DIR)
    FileUtils.mkdir(TEST_DATA_DIR)
    Geminabox.data = TEST_DATA_DIR
  end

  def self.fixture(path)
    File.join(File.expand_path("../fixtures", __FILE__), path)
  end

  def fixture(*args)
    self.class.fixture(*args)
  end


  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(File::NULL)
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
  end

  def silence
    silence_stream($stderr) do
      silence_stream($stdout) do
        yield
      end
    end
  end

  def inject_gems(&block)
    silence do
      yield GemFactory.new(File.join(Geminabox.data, "gems"))
      Gem::Indexer.new(Geminabox.data).generate_index
    end
  end

end
