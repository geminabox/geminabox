# frozen_string_literal: true

require 'sinatra/base'

module Geminabox
  module Hostess

    def self.included(app)
      app.class_eval do
        %w[/specs.4.8.gz
           /latest_specs.4.8.gz
           /prerelease_specs.4.8.gz
        ].each do |index|
          get index do
            content_type 'application/x-gzip'
            if Geminabox.rubygems_proxy
              serve_proxied(Proxy::Splicer.make(index[1..-1]))
            else
              serve_local_file
            end
          end
        end

        get '/quick/Marshal.4.8/*.gemspec.rz' do
          content_type('application/x-deflate')
          if Geminabox.rubygems_proxy
            serve_proxied(Proxy::Copier.copy(request.path_info[1..-1]))
          else
            serve_local_file
          end
        end

        get "/gems/*.gem" do
          if Geminabox.rubygems_proxy
            retrieve_from_rubygems_if_not_local
          else
            serve_local_file
          end
        end
      end
    end

    private

    def serve_local_file
      headers["Cache-Control"] = 'no-transform'
      file_path = File.expand_path(File.join(Geminabox.data, *request.path_info))
      send_file(file_path, :type => response['Content-Type'])
    end

    def serve_proxied(file_handler)
      headers["Cache-Control"] = 'no-transform'
      send_file file_handler.proxy_path
    end

    def retrieve_from_rubygems_if_not_local
      gem_path = request.path_info[1..-1]
      file = File.expand_path(File.join(Geminabox.data, gem_path))

      return serve if File.exist?(file)

      cache_path = RemoteCache.new.cache(gem_path) do
        ruby_gems_url = Geminabox.ruby_gems_url
        path = URI.join(ruby_gems_url, gem_path)
        Geminabox.http_adapter.get_content(path)
      end

      headers["Cache-Control"] = 'no-transform'
      send_file(cache_path, :type => response['Content-Type'])
    end

  end
end
