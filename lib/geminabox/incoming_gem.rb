# frozen_string_literal: true

module Geminabox

  class IncomingGem
    CANONICAL_VERSION = /\A#{Gem::Version::VERSION_PATTERN}\z/
    PLATFORM_CHARS = /\A[a-zA-Z0-9_.-]+\z/
    private_constant :CANONICAL_VERSION, :PLATFORM_CHARS

    def initialize(gem_data, root_path = Geminabox.data)
      unless gem_data.respond_to? :read
        raise ArgumentError, "Expected an instance of IO"
      end

      digest = Digest::SHA1.new
      @tempfile = Tempfile.new("gem", encoding: "binary", binmode: true)

      while data = gem_data.read(1024**2)
        @tempfile.write data
        digest << data
      end

      @tempfile.close
      @sha1 = digest.hexdigest

      @root_path = root_path
    end

    def gem_data
      File.open(@tempfile.path, "rb")
    end

    # spec comes from the uploaded archive and RubyGems does not validate it on
    # read, so the name must be checked before it becomes part of a path.
    def valid?
      metadata_within_limit? && safe_filename? && indexable?
    rescue Gem::Package::Error, Zlib::Error
      false
    end

    def spec
      @spec ||= Gem::Package.new(@tempfile.path).spec
    end

    def name
      @name ||= get_name
    end

    def get_name
      filename = %W[#{spec.name} #{spec.version}]
      filename.push(spec.platform) if spec.platform && spec.platform != "ruby"
      filename.join("-") + ".gem"
    end

    def dest_filename
      File.join(@root_path, "gems", name)
    end

    def hexdigest
      @sha1
    end

    private

    def safe_filename?
      spec && spec.name && spec.version &&
        spec.name.match?(Gem::Specification::VALID_NAME_PATTERN) &&
        File.basename(name) == name
    end

    def indexable?
      loadable_version?(spec.version) &&
        indexable_platform? &&
        spec.dependencies.all? { |dep| valid_dependency?(dep) } &&
        valid_requirement?(spec.required_ruby_version) &&
        valid_requirement?(spec.required_rubygems_version)
    end

    # Gem::Package#spec parses the spec YAML into roughly 50x its size in
    # memory and allows up to 10 MiB of it, once per upload and again on every
    # full reindex, so the cap is checked before anything is parsed. RubyGems
    # parses every metadata entry, so all of them are measured.
    # checksums.yaml.gz is YAML-parsed the same way, before the spec, so it
    # gets the same cap; a real one is a few hundred bytes.
    def metadata_within_limit?
      limit = Geminabox.max_metadata_size
      return true if limit.nil?
      # The pre-2007 format keeps the YAML inline; the file size bounds it.
      return File.size(@tempfile.path) <= limit if Gem::Package.new(@tempfile.path).is_a?(Gem::Package::Old)

      File.open(@tempfile.path, "rb") do |io|
        Gem::Package::TarReader.new(io).each do |entry|
          case entry.full_name
          when "metadata"
            return false if entry.size > limit
          when "metadata.gz", "checksums.yaml.gz"
            return false unless inflates_within?(entry, limit)
          end
        end
      end
      true
    end

    def inflates_within?(entry, limit)
      Zlib::GzipReader.wrap(entry) do |gz|
        total = 0
        while (chunk = gz.read(64 * 1024))
          total += chunk.bytesize
          return false if total > limit
        end
      end
      true
    end

    # Gem::Version re-parses its string on Marshal.load, so one bad version in
    # the specs index makes every later load of the index raise. The string is
    # also written raw into filenames and compact-index lines, so whitespace
    # that Gem::Version.correct? tolerates (and Gem::Version.new strips) is
    # rejected too.
    def loadable_version?(version)
      version.is_a?(Gem::Version) && version.version.is_a?(String) &&
        version.version.match?(CANONICAL_VERSION)
    end

    # The gem is stored under its normalised platform, but the indexer records
    # the original string, so a legacy alias (i686-linux, mswin32, jruby)
    # points clients at a file that does not exist.
    def indexable_platform?
      spec.original_platform.is_a?(String) &&
        spec.original_platform.match?(PLATFORM_CHARS) &&
        name == "#{spec.original_name}.gem"
    end

    # nil is what an older spec without the field reads back as.
    def valid_requirement?(requirement)
      return true if requirement.nil?

      requirement.is_a?(Gem::Requirement) &&
        requirement.requirements.all? do |op, version|
          Gem::Requirement::OPS.key?(op) && loadable_version?(version)
        end
    end

    # Dependency names and requirements are written verbatim into the
    # line-oriented compact index and Marshalled into the specs index.
    def valid_dependency?(dep)
      dep_name = dep.name.is_a?(Array) ? dep.name.first : dep.name
      dep_name.is_a?(String) &&
        dep_name.match?(Gem::Specification::VALID_NAME_PATTERN) &&
        valid_requirement?(dep.requirement)
    end
  end

end
