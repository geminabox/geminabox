# frozen_string_literal: true

require 'rubygems'
require 'digest/md5'
require 'builder'
require 'sinatra/base'
require 'rubygems/user_interaction'
require 'rubygems/indexer'
require 'rubygems/package'
require 'tempfile'
require 'json'
require 'tilt/erb'
require 'rack/protection'
require 'pathname'
require 'fileutils'
require 'parallel'

module Geminabox

  class Error < StandardError ; end

  require_relative 'geminabox/version'
  require_relative 'geminabox/proxy'
  require_relative 'geminabox/http_adapter'
  require_relative 'geminabox/user_interaction'

  def self.geminabox_path(file)
    File.join File.dirname(__FILE__), 'geminabox', file
  end

  autoload :Hostess,                 geminabox_path('hostess')
  autoload :GemStore,                geminabox_path('gem_store')
  autoload :GemStoreError,           geminabox_path('gem_store_error')
  autoload :RubygemsDependency,      geminabox_path('rubygems_dependency')
  autoload :GemListMerge,            geminabox_path('gem_list_merge')
  autoload :GemVersionsMerge,        geminabox_path('gem_versions_merge')
  autoload :GemVersion,              geminabox_path('gem_version')
  autoload :GemVersionCollection,    geminabox_path('gem_version_collection')
  autoload :Server,                  geminabox_path('server')
  autoload :DiskCache,               geminabox_path('disk_cache')
  autoload :RemoteCache,             geminabox_path('remote_cache')
  autoload :IncomingGem,             geminabox_path('incoming_gem')
  autoload :CompactIndexApi,         geminabox_path('compact_index_api')
  autoload :CompactIndexer,          geminabox_path('compact_indexer')
  autoload :RubygemsCompactIndexApi, geminabox_path('rubygems_compact_index_api')
  autoload :DependencyInfo,          geminabox_path('dependency_info')
  autoload :VersionInfo,             geminabox_path('version_info')
  autoload :Specs,                   geminabox_path('specs')
  autoload :Indexer,                 geminabox_path('indexer')
  autoload :ParallelSpecReader,      geminabox_path('parallel_spec_reader')

  class << self

    attr_accessor(
      :data,
      :public_folder,
      :views,
      :allow_replace,
      :gem_permissions,
      :allow_delete,
      :rubygems_proxy,
      :http_adapter,
      :lockfile,
      :retry_interval,
      :allow_remote_failure,
      :ruby_gems_url,
      :bundler_ruby_gems_url,
      :allow_upload,
      :on_gem_received,
      :workers
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

    def call(env)
      Server.call env
    end
  end

  set_defaults(
    data:                           File.join(File.dirname(__FILE__), *%w[.. data]),
    public_folder:                  File.join(File.dirname(__FILE__), *%w[.. public]),
    views:                          File.join(File.dirname(__FILE__), *%w[.. views]),
    allow_replace:                  false,
    gem_permissions:                0644,
    rubygems_proxy:                 (ENV['RUBYGEMS_PROXY'] == 'true'),
    allow_delete:                   true,
    http_adapter:                   HttpClientAdapter.new,
    lockfile:                       File.join(ENV.fetch('TMPDIR', Dir.tmpdir), 'geminabox.lockfile'),
    retry_interval:                 60,
    allow_remote_failure:           false,
    ruby_gems_url:                  'https://rubygems.org/',
    bundler_ruby_gems_url:          'https://bundler.rubygems.org/',
    allow_upload:                   true,
    on_gem_received:                nil,
    workers:                        10
  )

end
