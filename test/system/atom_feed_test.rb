require 'test_helper'
require 'minitest/unit'

module GeminaboxSystemTest
  attr_accessor :last_response 

  def self.included(klass)
    Assume.local_server_running
  end
  
  def get(relative_uri)
    @last_response = internet.get "http://localhost:9292#{relative_uri}"
  end

  private

  def internet
    Geminabox::HttpClientAdapter.new
  end
end

module Assume
  class << self
    def local_server_running
      earl = "http://localhost:9292/"

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
  
  test "atom feed returns when no gems are defined" do
    get "/atom.xml"
    
    assert last_response.ok?
    
    refute_match %r{<entry>}, last_response.body
  end
end