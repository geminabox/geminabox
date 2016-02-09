require 'sinatra/base'
require 'net/http'

module Geminabox
  module Proxy
    class Hostess < Sinatra::Base
      attr_accessor :file_handler
      
      def serve
        if file_handler
          send_file file_handler.proxy_path
        else
          send_file(File.expand_path(File.join(Server.data, *request.path_info)), :type => response['Content-Type'])
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

      %w[quick/Marshal.4.8/*.gemspec.rz
         yaml.Z
         Marshal.4.8.Z
      ].each do |deflated_index|
        get "/#{deflated_index}" do
          copy_file request.path_info[1..-1]
          content_type('application/x-deflate')
          serve
        end
      end

      %w[yaml
         Marshal.4.8
         specs.4.8
         latest_specs.4.8
         prerelease_specs.4.8
      ].each do |old_index|
        get "/#{old_index}" do
          splice_file old_index
          serve
        end
      end

      get "/gems/*.gem" do
        get_from_rubygems_if_not_local
        serve
      end

      private
      def get_from_rubygems_if_not_local

        file = File.expand_path(File.join(Server.data, *request.path_info))

        unless File.exists?(file)
          ruby_gems_url = 'https://rubygems.org'
          path = File.join(ruby_gems_url, *request.path_info)
          content = Geminabox.http_adapter.get_content(path)
          GemStore.create(IncomingGem.new(StringIO.new(content)))
        end

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
