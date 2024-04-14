# frozen_string_literal: true

module Geminabox
  module RubygemsAdapter
    def self.adapter_path(file)
      File.join File.dirname(__FILE__), 'rubygems_adapter', file
    end

    autoload :IndexApi,       adapter_path('index_api')
    autoload :DependencyApi,  adapter_path('dependency_api')
  end
end
