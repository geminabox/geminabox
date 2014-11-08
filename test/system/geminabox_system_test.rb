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
