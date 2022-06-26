module Geminabox
  class VersionInfo
    attr_reader :versions, :digests

    class << self
      def default_path
        CompactIndexer.versions_path
      end
    end

    def initialize(path = nil)
      @path = path || self.class.default_path
      @digests = {}
      @versions = {}
    end

    def exists?
      File.exist?(@path)
    end

    def update_gem_versions(dependency_info)
      gem_name = dependency_info.gem_name
      @versions[gem_name] = dependency_info.version_names.join(",")
      @digests[gem_name] = dependency_info.digest
    end

    def content(io = StringIO.new)
      io.write version_file_preamble
      versions.keys.sort.each do |name|
        io.puts [name, @versions[name], @digests[name]].join(" ")
      end
    end

    def write(dest_path = nil)
      dest_path ||= self.class.default_path
      File.open(dest_path, "wb") do |file|
        content(file)
      end
    end

    def version_file_preamble
      "created_at: #{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%L%z')}\n---\n"
    end

    def load_versions
      return unless exists?

      File.read(@path).each_line do |line|
        next if line =~ /^(---|created_at:)/

        gem_name, gem_versions, info_digest = line.chomp.split
        @versions[gem_name] = gem_versions
        @digests[gem_name] = info_digest
      end
    end

  end
end
