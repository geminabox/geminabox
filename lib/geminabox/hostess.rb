# frozen_string_literal: true

require 'sinatra/base'

module Geminabox

  class Hostess < Sinatra::Base
    def serve
      headers["Cache-Control"] = 'no-transform'
      send_file(File.expand_path(File.join(Geminabox.data, *request.path_info)), :type => response['Content-Type'])
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

    get '/quick/Marshal.4.8/*.gemspec.rz' do
      content_type('application/x-deflate')
      serve
    end

    get "/gems/*.gem" do
      serve
    end

  end
end
