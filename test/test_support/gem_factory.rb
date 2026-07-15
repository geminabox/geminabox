require 'rubygems/package'

class GemFactory
  def self.gem_file(*args)
    new(File.join(Dir.tmpdir, "geminabox-fixtures")).gem(*args)
  end

  def initialize(path)
    @path = Pathname.new(File.expand_path(path))
  end

  def gem(name, options = {})
    version  = options[:version] || "1.0.0"
    platform = options[:platform] || "ruby"

    requested_deps = []
    dependencies = options.fetch(:deps, {}).collect do |dep, requirement|
      dep = [*dep]
      gem(*dep)
      requested_deps << [dep.first.to_s, requirement_string(requirement)]
      if requirement
        "s.add_dependency(#{dep.first.to_s.inspect}, #{requirement.inspect})"
      else
        "s.add_dependency(#{dep.first.to_s.inspect})"
      end
    end.join("\n")

    name = name.to_s
    filename = %W[#{name} #{version}]
    filename.push(platform) if platform != "ruby"
    path = @path.join("#{filename.join("-")}.gem")
    FileUtils.mkdir_p File.dirname(path)

    # The cache key is the filename (name-version-platform); dependencies are
    # baked into the .gem but are not part of that key. Reuse a cached build
    # only when its dependencies match too, so a gem built once with one
    # dependency set is never handed back to a later caller that asked for the
    # same version with a different one.
    build_gem(path, name, version, platform, dependencies) unless cached?(path, requested_deps)
    path
  end

  private

  def cached?(path, requested_deps)
    return false unless File.exist?(path)

    actual = Gem::Package.new(path.to_s).spec.dependencies
                         .select { |dep| dep.type == :runtime }
                         .map { |dep| [dep.name, dep.requirement.to_s] }
    actual.sort == requested_deps.sort
  rescue StandardError
    false # an unreadable or corrupt cached gem is rebuilt rather than trusted
  end

  def requirement_string(requirement)
    requirement ? Gem::Requirement.new(requirement).to_s : Gem::Requirement.default.to_s
  end

  def build_gem(path, name, version, platform, dependencies)
    spec = %{
      Gem::Specification.new do |s|
        s.name              = #{name.inspect}
        s.version           = #{version.inspect}
        s.platform          = #{platform.inspect}
        s.summary           = #{name.inspect}
        s.description       = s.summary + " description"
        s.author            = 'Test'
        s.files             = []
        s.email             = 'fake@fake.fake'
        s.homepage          = 'http://fake.fake/fake'
        s.licenses          = ['Nonstandard']
        #{dependencies}
      end
    }

    Tempfile.open("spec") do |tmpfile|
      tmpfile << spec
      tmpfile.close

      Dir.chdir File.dirname(path) do
        system "gem build --silent #{tmpfile.path}"
      end
    end

    raise "Failed to build gem #{name}" unless File.exist? path
  end
end
