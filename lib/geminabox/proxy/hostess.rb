# frozen_string_literal: true

require 'sinatra/base'
require 'net/http'

module Geminabox
  module Proxy
    class Hostess < Sinatra::Base
      attr_accessor :file_handler
      def serve
        headers["Cache-Control"] = 'no-transform'
        if file_handler
          send_file file_handler.proxy_path
        else
          send_file(File.expand_path(File.join(Geminabox.data, *request.path_info)), :type => response['Content-Type'])
        end
      end

      %w[specs.4.8.gz
         latest_specs.4.8.gz
         prerelease_specs.4.8.gz
      ].each do |index|
        get "/#{index}" do
          splice_file index
          content_type 'application/x-gzip'
          serve
        end
      end

      get 'quick/Marshal.4.8/*.gemspec.rz' do
        copy_file request.path_info[1..-1]
        content_type('application/x-deflate')
        serve
      end

      get "/gems/*.gem" do
        get_from_rubygems_if_not_local
      end

      private

      def get_from_rubygems_if_not_local
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

      def splice_file(file_name)
        self.file_handler = Splicer.make(file_name)
      end

      def copy_file(file_name)
        self.file_handler = Copier.copy(file_name)
      end


    end
  end
end
