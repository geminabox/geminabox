# frozen_string_literal: true

module Geminabox
  module RubygemsDependency
    class << self
      def for(*gems)
        case Geminabox.rubygems_adapter
        when :dependency_api, :dependency
          Geminabox::RubygemsAdapter::DependencyApi.for(*gems)
        else
          Geminabox::RubygemsAdapter::IndexApi.for(*gems)
        end
      end
    end
  end
end
