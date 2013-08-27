require "rubygems"
gem "bundler"
require "bundler/setup"

require 'geminabox'
require 'minitest/autorun'
require 'fileutils'
require 'test_support/gem_factory'
require 'test_support/geminabox_test_case'

require 'capybara/mechanize'
require 'capybara/dsl'


Capybara.default_driver = :mechanize
Capybara.app_host = "http://localhost"
module TestMethodMagic
  def test(test_name, &block)
    define_method "test_method: #{test_name} ", &block
  end
end

class Minitest::Test
  extend TestMethodMagic

  TEST_DATA_DIR="/tmp/geminabox-test-data"
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
    stream.reopen('/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
  end

  def silence
    silence_stream(STDERR) do
      silence_stream(STDOUT) do
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

