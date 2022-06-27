require 'uri'

module Geminabox
  module RubygemsNames
    class << self

      def fetch
        Geminabox.http_adapter.get_content(rubygems_uri)
      rescue StandardError => e
        return if Geminabox.allow_remote_failure

        raise e
      end

      def rubygems_uri
        URI.join(Geminabox.bundler_ruby_gems_url, '/names')
      end

    end
  end
end
