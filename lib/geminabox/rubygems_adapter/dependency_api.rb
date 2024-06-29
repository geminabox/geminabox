# frozen_string_literal: true

module Geminabox
  module RubygemsAdapter
    module DependencyApi
      class << self
        def for(*gems)
          url = rubygems_uri.tap do |uri|
            uri.query = URI.encode_www_form(gems: gems.map(&:to_s).join(','))
          end

          body = Geminabox.http_adapter.get_content(url)
          Marshal.load(body)
        rescue StandardError => e
          return [] if Geminabox.allow_remote_failure

          raise e
        end

        private

        def rubygems_uri
          URI.join(Geminabox.bundler_ruby_gems_url, '/api/v1/dependencies')
        end
      end
    end
  end
end
