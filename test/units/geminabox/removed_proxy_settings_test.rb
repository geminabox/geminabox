# frozen_string_literal: true

require_relative '../../test_helper'

module Geminabox
  class RemovedProxySettingsTest < Minitest::Test
    REMOVED_SETTINGS = [
      :rubygems_proxy,
      :rubygems_proxy_merge_strategy,
      :allow_remote_failure,
      :ruby_gems_url,
      :bundler_ruby_gems_url
    ].freeze

    def test_removed_setting_writers_warn_and_do_not_raise
      REMOVED_SETTINGS.each do |setting|
        _out, err = capture_io do
          Geminabox.public_send("#{setting}=", true)
        end
        assert_match(/Geminabox\.#{setting} was removed in Geminabox 4\.0/, err)
      end
    end

    def test_removed_setting_readers_return_nil
      REMOVED_SETTINGS.each do |setting|
        assert_nil Geminabox.public_send(setting)
      end
    end

    def test_removed_env_var_warns_at_require_time
      output = IO.popen(
        { 'RUBYGEMS_PROXY' => 'true' },
        [Gem.ruby, '-Ilib', '-e', 'require "geminabox"'],
        err: [:child, :out],
        &:read
      )
      assert_match(/RUBYGEMS_PROXY.*removed in Geminabox 4\.0/m, output)
    end
  end
end
