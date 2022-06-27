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

module Geminabox

  class Error < StandardError ; end

  require_relative 'geminabox/version'
  require_relative 'geminabox/proxy'
  require_relative 'geminabox/http_adapter'

  def self.geminabox_path(file)
    File.join File.dirname(__FILE__), 'geminabox', file
  end

  autoload :Hostess,                geminabox_path('hostess')
  autoload :GemStore,               geminabox_path('gem_store')
  autoload :GemStoreError,          geminabox_path('gem_store_error')
  autoload :RubygemsDependency,     geminabox_path('rubygems_dependency')
  autoload :RubygemsVersions,       geminabox_path('rubygems_versions')
  autoload :RubygemsInfo,           geminabox_path('rubygems_info')
  autoload :GemListMerge,           geminabox_path('gem_list_merge')
  autoload :GemVersionsMerge,       geminabox_path('gem_versions_merge')
  autoload :GemVersion,             geminabox_path('gem_version')
  autoload :GemVersionCollection,   geminabox_path('gem_version_collection')
  autoload :Server,                 geminabox_path('server')
  autoload :DiskCache,              geminabox_path('disk_cache')
  autoload :IncomingGem,            geminabox_path('incoming_gem')
  autoload :CompactIndexer,         geminabox_path('compact_indexer')
  autoload :DependencyInfo,         geminabox_path('dependency_info')
  autoload :VersionInfo,            geminabox_path('version_info')
  autoload :Specs,                  geminabox_path('specs')
  autoload :Indexer,                geminabox_path('indexer')

  class << self

    attr_accessor(
      :data,
      :public_folder,
      :incremental_updates,
      :views,
      :allow_replace,
      :gem_permissions,
      :allow_delete,
      :rubygems_proxy,
      :rubygems_proxy_merge_strategy,
      :compact_index,
      :http_adapter,
      :lockfile,
      :retry_interval,
      :allow_remote_failure,
      :ruby_gems_url,
      :bundler_ruby_gems_url,
      :allow_upload,
      :on_gem_received
    )

    attr_reader :build_legacy

    def build_legacy=(value)
      warn "Setting `Geminabox.build_legacy` is deprecated and will be removed in the future. Geminbox will always build modern indices"

      @build_legacy = value
    end

    def set_defaults(defaults)
      defaults.each do |method, default|
        variable = "@#{method}"
        instance_variable_set(variable, default) unless instance_variable_get(variable)
      end
    end

    def supported_compact_index_configuration?
      compact_index && rubygems_proxy_merge_strategy != :combine_local_and_remote_gem_versions
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
    build_legacy:                   false,
    incremental_updates:            true,
    views:                          File.join(File.dirname(__FILE__), *%w[.. views]),
    allow_replace:                  false,
    gem_permissions:                0644,
    rubygems_proxy:                 (ENV['RUBYGEMS_PROXY'] == 'true'),
    rubygems_proxy_merge_strategy:  ENV.fetch('RUBYGEMS_PROXY_MERGE_STRATEGY') { :local_gems_take_precedence_over_remote_gems }.to_sym,
    compact_index:                  true,
    allow_delete:                   true,
    http_adapter:                   HttpClientAdapter.new,
    lockfile:                       File.join(ENV.fetch('TMPDIR', Dir.tmpdir), 'geminabox.lockfile'),
    retry_interval:                 60,
    allow_remote_failure:           false,
    ruby_gems_url:                  'https://rubygems.org/',
    bundler_ruby_gems_url:          'https://bundler.rubygems.org/',
    allow_upload:                   true,
    on_gem_received:                nil
  )

end
