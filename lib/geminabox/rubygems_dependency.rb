# frozen_string_literal: true

require 'json'
require 'uri'

module Geminabox
  module RubygemsDependency

    class << self

      def for(*gems)

        url = [
          rubygems_uri,
          '?gems=',
          gems.map(&:to_s).join(',')
        ].join
        body = Geminabox.http_adapter.get_content(url)
        Marshal.load(body)
      rescue StandardError => e
        return [] if Geminabox.allow_remote_failure
        raise e
      end

      def rubygems_uri
        URI.join(Geminabox.bundler_ruby_gems_url, '/api/v1/dependencies')
      end

    end
  end
end

