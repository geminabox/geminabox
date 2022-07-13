require 'time'

module Geminabox
  module GemVersionsMerge
    def self.merge(local_gem_list, remote_gem_list)
      return local_gem_list unless remote_gem_list

      local_split = local_gem_list.split("\n")
      remote_split = remote_gem_list.split("\n")

      combined = gems_hash(remote_split).merge(gems_hash(local_split))

      preamble = younger_created_at_header(local_split, remote_split)

      "#{(preamble + combined.values.sort).join("\n")}\n"
    end

    def self.younger_created_at_header(local_split, remote_split)
      t1 = Time.parse(local_split[0].split[1])
      t2 = Time.parse(remote_split[0].split[1])
      (t1 > t2 ? local_split : remote_split)[0..1]
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
