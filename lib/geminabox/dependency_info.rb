# frozen_string_literal: true

module Geminabox
  class DependencyInfo
    attr_reader :gem_name

    def initialize(gem_name)
      @gem_name = gem_name
      @versions = nil
      @content = nil
      yield self if block_given?
    end

    def versions
      @versions ||= decode
    end

    def version_names
      versions.map { |version, platform, _, _| version_name(version, platform) }
    end

    def versions=(versions)
      @versions ||= versions
      @content = nil
    end

    def content
      @content ||= encode
    end

    def content=(content)
      @content = content
      @versions = nil
    end

    def digest
      Digest::MD5.hexdigest(content)
    end

    def checksums
      versions.map { |v| checksum(v) }
    end

    def add_gem_spec_and_gem_checksum(spec, checksum)
      raise ArgumentError, "can't add spec for gem #{spec.name} to gem info for gem #{gem_name}" if spec.name != gem_name

      platform = spec.platform.to_s if spec.platform && spec.platform != 'ruby'
      dependencies = dependencies_from_spec(spec)
      requirements = requirements_from_spec(spec, checksum)

      add_gem_version(spec.version.to_s, platform, dependencies, requirements)
      @content = nil
    end

    def remove_gem_spec(spec)
      raise ArgumentError, "can't remove spec for gem #{spec.name} from gem info for gem #{gem_name}" if spec.name != gem_name

      version_to_delete = GemVersion.from_spec(spec)

      versions.reject! do |version, platform, _, _|
        version_to_delete == gem_version(version, platform)
      end
      @content = nil
    end

    def subsumed_by?(other)
      Set.new(checksums) <= Set.new(other.checksums)
    end

    def disjoint?(other)
      !Set.new(checksums).intersect?(Set.new(other.checksums))
    end

    def conflicts(other)
      other_checksums = Set.new(other.checksums)
      local_versions = versions.reject { |v| other_checksums.include?(checksum(v)) }
      local_versions.map { |v, p, _, _| version_name(v, p) }
    end

    private

    PREAMBLE = "---\n"

    def decode(content = @content)
      content.to_s.each_line.map { |line| parse_line(line.chomp) unless line == PREAMBLE }.compact
    end

    def encode(versions = @versions)
      str = PREAMBLE.dup
      return str unless versions

      versions.each do |version, platform, dependencies, requirements|
        str << version_name(version, platform)
        str << " "
        str << print_dependencies(dependencies)
        str << "|"
        str << print_dependencies(requirements)
        str << "\n"
      end
      str
    end

    def version_name(version, platform = nil)
      str = version.dup
      str << "-" << platform.to_s if platform && platform != 'ruby'
      str
    end

    def parse_line(line)
      version_and_platform, rest = line.split(" ", 2)
      version, platform = version_and_platform.split("-", 2)
      dependencies, requirements = rest.split("|", 2).map { |s| s.split(",") } if rest
      dependencies = dependencies ? dependencies.map { |d| parse_dependency(d) } : []
      requirements = requirements ? requirements.map { |d| parse_dependency(d) } : []
      [version, platform, dependencies, requirements]
    end

    def parse_dependency(string)
      dependency = string.split(":")
      dependency[-1] = dependency[-1].split("&") if dependency.size > 1
      dependency
    end

    def print_dependencies(dependencies)
      dependencies.map { |dep| print_dependency(dep) }.join(",")
    end

    def print_dependency(dependency)
      name, constraints = dependency
      [name, constraints.join("&")].join(":")
    end

    UNCONSTRAINED = Gem::Requirement.new([">= 0"])

    def unconstrained?(requirement)
      requirement <=> UNCONSTRAINED
    end

    def constraints_for(name, requirement)
      return [] if unconstrained?(requirement)

      [[name, requirement.requirements.sort.map { |a| a.join(" ") }]]
    end

    def add_gem_version(version, platform, dependencies, requirements)
      versions.reject! { |v, p, _, _| v == version && p == platform }
      versions << [version, platform, dependencies, requirements]
      versions.sort_by! { |v, p, _, _| gem_version(v, p) }
    end

    def gem_version(version, platform)
      GemVersion.new(gem_name, version, platform)
    end

    def checksum(version)
      version[3].find { |n, _| n == "checksum" }[1].first
    end

    def dependencies_from_spec(spec)
      spec.runtime_dependencies.sort.map { |dep| requirements_from_dep(dep) }
    end

    def requirements_from_dep(dep)
      [dep.name, dep.requirement.requirements.sort.map { |a| a.join(" ") }]
    end

    def requirements_from_spec(spec, checksum)
      requirements = [['checksum', [checksum]]]
      requirements += constraints_for('ruby', spec.required_ruby_version)
      requirements += constraints_for('rubygems', spec.required_rubygems_version)
      requirements
    end
  end
end
