require 'test_helper'
require 'minitest/unit'
require 'rack/test'

class AtomFeedTest < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  def setup
    clean_data_dir
  end

  def app
    Geminabox
  end

  test 'atom feed returns when no gems are defined' do
    get '/atom.xml'
    assert last_response.ok?
    refute_match %r{<entry>}, last_response.body
  end

  test 'atom feed with a single gem' do
    skip 'Test broken under Win32.' if RbConfig::CONFIG['host_os'] =~ /mswin|windows|cygwin|mingw32/i
    inject_gems do |builder|
      builder.gem "foo"
    end

    get "/atom.xml"
    assert last_response.ok?
    feed_content = RSS::Parser.parse(last_response.body)
    feed_content.items.size == 1
  end
end
