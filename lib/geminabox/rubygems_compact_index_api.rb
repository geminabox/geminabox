require 'uri'

module Geminabox
  module RubygemsCompactIndexApi
    class << self

      def fetch_info(gem_name)
        fetch("/info/#{gem_name}")
      end

      def fetch_versions
        fetch('/versions')
      end

      def fetch_names
        fetch('/names')
      end

      def fetch(path)
        Geminabox.http_adapter.get_content(rubygems_uri(path))
      rescue StandardError
        return if Geminabox.allow_remote_failure

        raise
      end

      def rubygems_uri(path)
        URI.join(Geminabox.bundler_ruby_gems_url, path)
      end

    end
  end
end
