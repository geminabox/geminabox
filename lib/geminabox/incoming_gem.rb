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
        File.basename(name) == name
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
  end

end
