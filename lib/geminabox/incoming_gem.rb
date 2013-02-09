class Geminabox::IncomingGem
  def initialize(gem_data, root_path = Geminabox.settings.data)
    unless gem_data.respond_to? :read
      raise ArgumentError, "Expected an instance of IO"
    end

    digest = Digest::SHA1.new
    if RbConfig::CONFIG["MAJOR"].to_i <= 1 and RbConfig::CONFIG["MINOR"].to_i <= 8
      @tempfile = Tempfile.new("gem")
    else
      @tempfile = Tempfile.new("gem", :encoding => 'binary')
    end

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

  def valid?
    spec && spec.name && spec.version
  rescue Gem::Package::Error
    false
  end

  def spec
    unless @spec
      Gem::Package.open(gem_data, "r", nil) do |pkg|
        @spec = pkg.metadata
      end
    end
    @spec
  end

  def name
    unless @name
      filename = %W[#{spec.name} #{spec.version}]
      filename.push(spec.platform) if spec.platform && spec.platform != "ruby"
      @name = filename.join("-") + ".gem"
    end
    @name
  end

  def dest_filename
    File.join(@root_path, "gems", name)
  end

  def hexdigest
    @sha1
  end
end
