module Geminabox
  module Specs
    module_function

    def all_gems
      all_gems_with_duplicates.inject(:|)
    end

    def all_gems_with_duplicates
      specs_files_paths.map do |specs_file_path|
        if File.exist?(specs_file_path)
          Marshal.load(Gem::Util.gunzip(Gem.read_binary(specs_file_path)))
        else
          []
        end
      end
    end

    def specs_file_types
      [:specs, :prerelease_specs]
    end

    def specs_files_paths
      specs_file_types.map do |specs_file_type|
        File.join(Geminabox.data, spec_file_name(specs_file_type))
      end
    end

    def spec_file_name(specs_file_type)
      [specs_file_type, Gem.marshal_version, 'gz'].join('.')
    end

    def checksum_for_version(version)
      filename = "#{version.gemfile_name}.gem"
      gem_file = File.join(Geminabox.data, "gems", filename)
      Digest::SHA256.file(gem_file).hexdigest if File.exist?(gem_file)
    end

    def spec_file_name_for_version(version)
      File.join(Geminabox.data, "quick", "Marshal.#{Gem.marshal_version}", "#{version.gemfile_name}.gemspec.rz")
    end

    def spec_for_version(version)
      spec_file = spec_file_name_for_version(version)
      return unless File.exist? spec_file

      File.open(spec_file, 'r') do |unzipped_spec_file|
        unzipped_spec_file.binmode
        Marshal.load(Gem::Util.inflate(unzipped_spec_file.read))
      end
    end
  end
end
