require 'httpclient'
require 'json'

module Geminabox
  module RubygemsDependency

    class << self

      def for(*gems)

        url = [
          rubygems_uri,
          '?gems=',
          gems.map(&:to_s).join(',')
        ].join
        body = HTTPClient.get_content(url)
        JSON.parse(body)
      end

      def rubygems_uri
        "https://bundler.rubygems.org/api/v1/dependencies.json"
      end

    end
  end
end

