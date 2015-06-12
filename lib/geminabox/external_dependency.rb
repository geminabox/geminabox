require 'json'

module Geminabox
  module ExternalDependency

    class << self

      def for(*gems)
        source_list = []
        Sources.external_sources.each do |source|
          url = [ external_uri(source), '?gems=', gems.map(&:to_s).join(',') ].join
          body = Geminabox.http_adapter.get_content(url)
          source_list << JSON.parse(body)
        end
        source_list
      rescue Exception => e
        return [] if Geminabox.allow_remote_failure
        raise e
      end

      def external_uri(source)
        "https://#{source.url}/api/v1/dependencies.json"
      end

    end
  end
end

