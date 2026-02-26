# frozen_string_literal: true

require 'uri'

module Geminabox
  module RubygemsAdapter
    module IndexApi
      class << self
        def for(*gems)
          gems.each_with_object([]) do |gem_name, accum|
            accum.push(*for_gem(gem_name))
          end
        rescue StandardError
          return [] if Geminabox.allow_remote_failure

          raise
        end

        private

        def rubygems_gem_uri(gem_name)
          URI.join(Geminabox.index_ruby_gems_url, "/info/#{URI.encode_www_form_component(gem_name.to_s)}")
        end

        def for_gem(gem_name)
          uri = rubygems_gem_uri(gem_name)
          response = Geminabox.http_adapter.get_content(uri)
          response.each_line.with_object([]) do |line, result|
            next unless line.include?('|')

            version_meta, _metadata = line.split('|')
            version_info, dependencies = version_meta.split(' ', 2)

            version, platform = version_info.split('-', 2)
            platform ||= "ruby"

            dependencies = dependencies.to_s.split(',').each_with_object([]) do |dep, accum|
              name, requirements = dep.split(':')
              requirements.split('&').each do |requirement|
                accum.push([name.strip, requirement.strip])
              end
            end

            data = {
              "name" => gem_name.to_s,
              "number" => version,
              "platform" => platform,
              "dependencies" => dependencies
            }

            result.push(data)
          end
        end
      end
    end
  end
end
