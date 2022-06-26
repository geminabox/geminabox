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

    def add_gem_spec_and_gem_checksum(spec, checksum)
      raise ArgumentError, "can't add spec for gem #{spec.name} to gem info for gem #{gem_name}" if spec.name != gem_name

      platform = spec.platform.to_s if spec.platform && spec.platform != 'ruby'
      dependencies = spec.runtime_dependencies.sort.map { |dep| [dep.name, dep.requirement.requirements.sort.map { |a| a.join(" ") }] }
      requirements = [['checksum', checksum]]
      requirements += constraints_for('ruby', spec.required_ruby_version)
      requirements += constraints_for('rubygems', spec.required_rubygems_version)
      add_gem_version(spec.version.to_s, platform, dependencies, requirements)
      @content = nil
    end

    private

    PREAMBLE = "---\n"

    def decode(content = @content)
      content.to_s.each_line.map { |line| parse_line(line.chomp) unless line == PREAMBLE }.compact
    end

    def encode(versions = @versions)
      str = PREAMBLE.dup
      if versions
        versions.each do |version, platform, dependencies, requirements|
          str << version_name(version, platform)
          str << " "
          str << print_dependencies(dependencies)
          str << "|"
          str << print_dependencies(requirements)
          str << "\n"
        end
      end
      str
    end

    def version_name(version, platform = nil)
      str = version.dup
      str << "-" << platform.to_s if platform && platform != RUBY_PLATFORM
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
      [name, Array(constraints).join("&")].join(":")
    end

    UNCONSTRAINED = Gem::Requirement.new([">= 0"])

    RUBY_PLATFORM = 'ruby'

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
      versions.sort_by! { |v, p, _, _| GemVersion.new(gem_name, v, p || RUBY_PLATFORM) }
    end
  end
end
