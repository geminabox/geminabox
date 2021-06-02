require 'uri'

module Geminabox
  module RubygemsInfo
    class << self

      def fetch(gem)
        Geminabox.http_adapter.get_content([rubygems_uri, "/#{gem}"].join)
      rescue StandardError => e
        return if Geminabox.allow_remote_failure

        raise e
      end

      def rubygems_uri
        URI.join(Geminabox.bundler_ruby_gems_url, '/info')
      end

    end
  end
end
