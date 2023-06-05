# frozen_string_literal: true

module Geminabox

  class IncomingGem
    def initialize(gem_data, root_path = Geminabox.data)
      unless gem_data.respond_to? :read
        raise ArgumentError, "Expected an instance of IO"
      end

      digest = Digest::SHA256.new
      @tempfile = Tempfile.new("gem", encoding: "binary", binmode: true)

      while data = gem_data.read(1024**2)
        @tempfile.write data
        digest << data
      end

      @tempfile.close
      @sha256 = digest.hexdigest

      @root_path = root_path
    end

    def gem_data
      File.open(@tempfile.path, "rb")
    end

    def valid?
      spec && spec.name && spec.version
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
      @sha256
    end
  end

end
