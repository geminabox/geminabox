require 'time'

module Geminabox
  class GemVersionsMerge
    include CompactIndexer::PathMethods
    attr_reader :local_gem_list, :remote_gem_list

    def initialize(local_gem_list, remote_gem_list)
      @local_gem_list = local_gem_list
      @remote_gem_list = remote_gem_list
    end

    def call
      return local_gem_list unless remote_gem_list

      Server.dependency_cache.marshal_cache("gem_merged_versions/#{preamble_time}") do
        combine_gems!(local_split)
        combine_gems!(remote_split)

        result = combined.flat_map do |name, digests|
          digests.map do |digest, versions|
            versions = versions.uniq.sort.join(',')
            [name, versions, digest].compact.join(' ')
          end
        end
        "#{(preamble + result.sort).join("\n")}\n"
      end
    end

    private

    def combined
      @combined ||= Hash.new { |h, k| h[k] = {} }
    end

    def local_split
      @local_split ||= local_gem_list&.split("\n") || []
    end

    def remote_split
      @remote_split ||= remote_gem_list.split("\n") || []
    end

    def local_time
      return Time.at(0) if local_split.empty?

      @local_time ||= Time.parse(local_split[0].split[1])
    end

    # default to the begging of time if the remote time is not available
    def remote_time
      return Time.at(0) if remote_split.empty?

      @remote_time ||= Time.parse(remote_split[0].split[1])
    end

    def preamble
      (local_time > remote_time ? local_split : remote_split)[0..1]
    end

    def preamble_time
      Time.parse(preamble[0].split[1])
    end

    def datadir
      Geminabox.data
    end

    def combine_gems!(source)
      return if source.empty?

      source[2..-1].each do |line, _hash|
        name, versions, digest = line.chomp.split
        versions = versions.split(',') + combined.dig(name, digest).to_a
        combined[name] ||= {}
        combined[name][digest] = versions
      end
    end
  end
end
