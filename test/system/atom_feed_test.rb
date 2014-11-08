require 'test_helper'
require 'minitest/unit'

module GeminaboxSystemTest
  attr_accessor :last_response 

  def get(relative_uri)
    @last_response = internet.get "#{base_earl}#{relative_uri}"
  end

  def delete(relative_uri)
    @last_response = internet.delete "#{base_earl}#{relative_uri}"
  end

  def push(gem)
    require 'geminabox_client'
    GeminaboxClient.new(base_earl).push gem
  end

  private
  
  def base_earl; Settings.base_earl; end

  def self.included(klass)
    Assume.local_server_running_at Settings.base_earl
  end  

  def internet
    Geminabox::HttpClientAdapter.new
  end
end

class Settings
  class << self
    def base_earl; 'http://localhost:9292'; end
  end
end

module Assume
  class << self
    def local_server_running_at(earl)
      begin 
        reply = Geminabox::HttpClientAdapter.new.get earl
        fail "Your local server is running at <#{earl}>, but returned unexpected status. #{reply.inspect}" unless reply.ok?
      rescue Exception => e
        fail "Your local server is not running at <#{earl}>."
      end
    end
  end
end

class AtomFeedTest < Minitest::Test
  include GeminaboxSystemTest
  
  def setup
    delete("/api/v1/gems")
  end

  test "atom feed returns when no gems are defined" do
    get "/atom.xml"
    
    assert last_response.ok?
    
    refute_match %r{<entry>}, last_response.body
  end

  test "atom feed with a single gem" do
    push File.join('.', 'samples', 'geminabox-0.12.4.gem')

    get("/atom.xml").body

    assert last_response.ok?
    feed_content = RSS::Parser.parse(last_response.body)
    feed_content.items.size == 1
  end
end
