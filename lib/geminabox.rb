module Geminabox

  require 'rubygems'
  require 'digest/md5'
  require 'builder'
  require 'sinatra/base'
  require 'rubygems/indexer'
  require 'rubygems/package'
  require 'geminabox/hostess'
  require 'geminabox/version'
  require 'geminabox/gem_store'
  require 'geminabox/gem_store_error'
  require 'geminabox/rubygems_dependency'
  require 'geminabox/gem_list_merge'
  require 'geminabox/gem_version'
  require 'geminabox/gem_version_collection'
  require 'geminabox/server'
  require 'geminabox/disk_cache'
  require 'geminabox/incoming_gem'
  require 'rss/atom'
  require 'tempfile'

  def self.settings
    Server.settings
  end

  def self.data
    Server.data
  end

  def self.data=(location)
    Server.data = location
  end
    
end
