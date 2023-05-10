require 'time'

module Geminabox
  module GemVersionsMerge
    extend CompactIndexer::PathMethods
    def self.datadir
      Geminabox.data
    end

    def self.merge(local_gem_list, remote_gem_list)
      return local_gem_list unless remote_gem_list
      merged_versions = try_load_cached_file

      local_split = local_gem_list.split("\n")
      remote_split = remote_gem_list.split("\n")
      merged_versions_split = merged_versions.split("\n")

      local_time = Time.parse(local_split[0].split[1])
      remote_time = Time.parse(remote_split[0].split[1])
      preamble = (local_time > remote_time ? local_split : remote_split)[0..1]
      unless merged_versions.empty?
        merged_version_time = Time.parse(merged_versions_split[0].split[1])
        preamble_time = Time.parse(preamble[0].split[1])
        return merged_versions if merged_version_time >= preamble_time
      end

      combined = gems_hash(remote_split).merge(gems_hash(local_split))
      result = "#{(preamble + combined.values.sort).join("\n")}\n"
      write_merged_versions(result)
      result
    end

    def self.write_merged_versions(file_content)
      File.write(merged_versions_path, file_content)
    end

    def self.try_load_cached_file
      File.exist?(merged_versions_path) && File.read(merged_versions_path) || ""
    end

    def self.gems_hash(source)
      source[2..-1].each_with_object({}) do |line, hash|
        line.chomp!
        name, versions, digest = line.split
        seen = hash[name]
        if seen
          seen_versions = seen.split[1]
          hash[name] = "#{name} #{seen_versions},#{versions} #{digest}"
        else
          hash[name] = line
        end
      end
    end
  end
end
