require 'json'

module Geminabox
  module ExternalDependency

    class << self

      def for(*gems)
        source_list = Sources.external_sources.inject([]) do |memo, source|
          memo << for_source(gems, source)
        end
        source_list.flatten.uniq
      rescue SocketError, HTTPClient::BadResponseError => e
        return [] if Geminabox.allow_remote_failure
        raise e
      end

      def for_source gems, source
        url = [ external_uri(source), '?gems=', gems.map(&:to_s).join(',') ].join
        body = Geminabox.http_adapter.get_content(url)
        JSON.parse(body)
      end

      def external_uri(source)
        "#{source}/api/v1/dependencies.json"
      end

    end
  end
end

