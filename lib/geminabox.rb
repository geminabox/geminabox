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
  require_relative 'geminabox/http_adapter'

  def self.geminabox_path(file)
    File.join File.dirname(__FILE__), 'geminabox', file
  end

  autoload :Hostess,                geminabox_path('hostess')
  autoload :GemStore,               geminabox_path('gem_store')
  autoload :GemStoreError,          geminabox_path('gem_store_error')
  autoload :GemVersion,             geminabox_path('gem_version')
  autoload :GemVersionCollection,   geminabox_path('gem_version_collection')
  autoload :CompactIndexer,         geminabox_path('compact_indexer')
  autoload :Server,                 geminabox_path('server')
  autoload :DiskCache,              geminabox_path('disk_cache')
  autoload :IncomingGem,            geminabox_path('incoming_gem')

  class << self

    attr_accessor(
      :data,
      :public_folder,
      :incremental_updates,
      :views,
      :allow_replace,
      :gem_permissions,
      :allow_delete,
      :http_adapter,
      :lockfile,
      :retry_interval,
      :allow_upload,
      :on_gem_received
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
    incremental_updates:            true,
    views:                          File.join(File.dirname(__FILE__), *%w[.. views]),
    allow_replace:                  false,
    gem_permissions:                0644,
    allow_delete:                   true,
    http_adapter:                   HttpClientAdapter.new,
    lockfile:                       File.join(ENV.fetch('TMPDIR', Dir.tmpdir), 'geminabox.lockfile'),
    retry_interval:                 60,
    allow_upload:                   true,
    on_gem_received:                nil
  )

  # Removed in 4.0 with the RubyGems proxy. Warn-and-ignore (rather than
  # NoMethodError at boot) so stale config.ru lines don't break upgrades.
  # Drop these shims in 5.0.
  [
    :rubygems_proxy,
    :rubygems_proxy_merge_strategy,
    :allow_remote_failure,
    :ruby_gems_url,
    :bundler_ruby_gems_url
  ].each do |setting|
    define_singleton_method("#{setting}=") do |_value|
      warn "[REMOVED] Geminabox.#{setting} was removed in Geminabox 4.0 " \
           'along with the RubyGems proxy and has no effect. Remove this ' \
           'line from your config.ru. Migration notes: ' \
           'https://github.com/geminabox/geminabox/pull/735'
    end
    define_singleton_method(setting) { nil }
  end

  if ENV['RUBYGEMS_PROXY'] == 'true' || ENV.key?('RUBYGEMS_PROXY_MERGE_STRATEGY')
    warn '[REMOVED] The RUBYGEMS_PROXY and RUBYGEMS_PROXY_MERGE_STRATEGY ' \
         'environment variables were removed in Geminabox 4.0; Geminabox ' \
         'now always serves only local gems. Migration notes: ' \
         'https://github.com/geminabox/geminabox/pull/735'
  end

end
