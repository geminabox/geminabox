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
        body = Geminabox.http_adapter.get_content(url)
        Marshal.load(body)
      rescue Exception => e
        return [] if Geminabox.allow_remote_failure
        raise e
      end

      def rubygems_uri
        "https://bundler.rubygems.org/api/v1/dependencies"
      end

    end
  end
end

