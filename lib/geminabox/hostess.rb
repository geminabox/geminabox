require 'sinatra/base'

module Geminabox

  class Hostess < Sinatra::Base
    def serve
      get_from_rubygems_if_not_local if Server.rubygems_proxy

      send_file(File.expand_path(File.join(Server.data, *request.path_info)), :type => response['Content-Type'])
    end

    def get_from_rubygems_if_not_local

      file = File.expand_path(File.join(Server.data, *request.path_info))

      unless File.exists?(file)
        Net::HTTP.start("production.cf.rubygems.org") do |http|
          path = File.join(*request.path_info)
          response = http.get(path)
          GemStore.create(IncomingGem.new(StringIO.new(response.body)))
        end
      end

    end

    %w[/specs.4.8.gz
       /latest_specs.4.8.gz
       /prerelease_specs.4.8.gz
    ].each do |index|
      get index do
        content_type('application/x-gzip')
        serve
      end
    end

    %w[/quick/Marshal.4.8/*.gemspec.rz
       /yaml.Z
       /Marshal.4.8.Z
    ].each do |deflated_index|
      get deflated_index do
        content_type('application/x-deflate')
        serve
      end
    end

    %w[/yaml
       /Marshal.4.8
       /specs.4.8
       /latest_specs.4.8
       /prerelease_specs.4.8
    ].each do |old_index|
      get old_index do
        serve
      end
    end

    get "/gems/*.gem" do
      serve
    end
  end
end
