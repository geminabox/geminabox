# frozen_string_literal: true

module Geminabox

  class IncomingGem
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
      spec && spec.name && spec.version &&
        spec.name.match?(Gem::Specification::VALID_NAME_PATTERN) &&
        File.basename(name) == name &&
        loadable_version?(spec.version) &&
        indexable_platform? &&
        spec.dependencies.all? { |dep| valid_dependency?(dep) }
    rescue Gem::Package::Error
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

    # Gem::Version re-parses its string on Marshal.load, so one bad version in
    # the specs index makes every later load of the index raise.
    def loadable_version?(version)
      version.is_a?(Gem::Version) && Gem::Version.correct?(version.version)
    end

    # The gem is stored under its normalised platform, but the indexer records
    # the original string, so a legacy alias (i686-linux, mswin32, jruby)
    # points clients at a file that does not exist.
    def indexable_platform?
      spec.original_platform.is_a?(String) && name == "#{spec.original_name}.gem"
    end

    # Dependency names and requirements are written verbatim into the
    # line-oriented compact index and Marshalled into the specs index.
    def valid_dependency?(dep)
      dep_name = dep.name.is_a?(Array) ? dep.name.first : dep.name
      dep_name.is_a?(String) &&
        dep_name.match?(Gem::Specification::VALID_NAME_PATTERN) &&
        dep.requirement.requirements.all? do |op, version|
          Gem::Requirement::OPS.key?(op) && loadable_version?(version)
        end
    end
  end

end
