require 'uri'

module Geminabox
  class RubygemsCompactIndexApi

    def fetch_info(gem_name, etag = nil)
      fetch("/info/#{gem_name}", etag)
    end

    def fetch_versions(etag = nil)
      fetch('/versions', etag)
    end

    def fetch_names(etag = nil)
      fetch('/names', etag)
    end

    private

    def fetch(path, etag)
      headers = { 'If-None-Match' => %("#{etag}") } if etag
      response = Geminabox.http_adapter.get(rubygems_uri(path), nil, headers)
      [response.code, response.body]
    rescue StandardError
      return [0, nil] if Geminabox.allow_remote_failure

      raise
    end

    def rubygems_uri(path)
      URI.join(Geminabox.bundler_ruby_gems_url, path)
    end

  end
end
