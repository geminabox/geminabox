module Geminabox
  class VersionInfo
    attr_reader :versions, :digests

    def initialize
      @digests = {}
      @versions = {}
      yield self if block_given?
    end

    def update_gem_versions(dependency_info)
      gem_name = dependency_info.gem_name
      version_names = dependency_info.version_names
      if version_names.empty?
        @versions.delete(gem_name)
        @digests.delete(gem_name)
      else
        @versions[gem_name] = version_names.join(",")
        @digests[gem_name] = dependency_info.digest
      end
    end

    def content(io = StringIO.new)
      io.write version_file_preamble
      versions.keys.sort.each do |name|
        io.puts [name, @versions[name], @digests[name]].join(" ")
      end
      return io.string if io.is_a?(StringIO)
    end

    def write(dest_path)
      File.open(dest_path, "wb") do |file|
        content(file)
      end
    end

    def version_file_preamble
      "created_at: #{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%L%z')}\n---\n"
    end

    def load_versions(path)
      self.content = File.read(path) if File.exist?(path)
    end

    def content=(data)
      reset
      data.split("\n").each do |line|
        parse_line(line)
      end
    end

    def parse_line(line)
      return if line =~ /^(---|created_at:)/

      gem_name, gem_versions, info_digest = line.chomp.split
      @versions[gem_name] = gem_versions
      @digests[gem_name] = info_digest
    end

    def reset
      @digests.clear
      @versions.clear
    end

  end
end
