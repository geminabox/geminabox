# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/streaming'

module Geminabox

  class Hostess < Sinatra::Base
    helpers Sinatra::Streaming

    def stream_file(file)
      f = File.open(File.expand_path(File.join(Geminabox.data, *request.path_info)), "r")

      stream do |out|
        until f.eof?
          out <<  f.read( 1024 * 1024 )
        end
      end
    end

    def serve
      cache_control "no-transform"
      content_type "application/octet-stream"

      stream_file file
    end

    %w[/specs.4.8.gz
       /latest_specs.4.8.gz
       /prerelease_specs.4.8.gz
    ].each do |index|
      get index do
        content_type 'application/x-gzip'
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
