require 'rubygems'
require 'digest/md5'
require 'builder'
require 'sinatra/base'
require 'rubygems/indexer'
require 'rubygems/package'
require 'rss/atom'
require 'tempfile'

module Geminabox

  autoload :Hostess,              'geminabox/hostess'
  autoload :VERSION,              'geminabox/version'
  autoload :GemStore,             'geminabox/gem_store'
  autoload :GemStoreError,        'geminabox/gem_store_error'
  autoload :RubygemsDependency,   'geminabox/rubygems_dependency'
  autoload :GemListMerge,         'geminabox/gem_list_merge'
  autoload :GemVersion,           'geminabox/gem_version'
  autoload :GemVersionCollection, 'geminabox/gem_version_collection'
  autoload :Server,               'geminabox/server'
  autoload :DiskCache,            'geminabox/disk_cache'
  autoload :IncomingGem,          'geminabox/incoming_gem'

  class << self

    attr_accessor(
      :data,
      :public_folder,
      :build_legacy,
      :incremental_updates,
      :views,
      :allow_replace,
      :gem_permissions,
      :allow_delete,
      :rubygems_proxy
    )

    def set_defaults(defaults)
      defaults.each do |method, default|
        variable = "@#{method}"
        instance_variable_set(variable, default) unless instance_variable_get(variable)
      end
    end

    def settings
      Server.settings
    end
  end

  set_defaults(

    data:                File.join(File.dirname(__FILE__), *%w[.. data]),
    public_folder:       File.join(File.dirname(__FILE__), *%w[.. public]),
    build_legacy:        false,
    incremental_updates: true,
    views:               File.join(File.dirname(__FILE__), *%w[.. views]),
    allow_replace:       false,
    gem_permissions:     0644,
    rubygems_proxy:      (ENV['RUBYGEMS_PROXY'] == 'true'),
    allow_delete:        true

  )
    
end
