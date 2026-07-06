# frozen_string_literal: true

require 'compact_index'
require 'digest'
require 'time'
require 'tempfile'
require 'tmpdir'
require 'fileutils'
require 'rubygems/util'

module Geminabox

  # Materializes the compact index API bodies (/versions, /info/NAME, /names)
  # under data/compact_index/, from the gems recorded in the legacy Marshal
  # specs indexes. Callers must hold the repository lock while writing.
  #
  # Invariant: the MD5 in every versions.list line is the MD5 of the exact
  # bytes of the info/NAME file current when the line was written.
  class CompactIndexer
    def initialize(data_dir = Geminabox.data)
      @data_dir = data_dir
    end

    def compact_index_dir
      File.join(@data_dir, "compact_index")
    end

    def versions_path
      File.join(compact_index_dir, "versions.list")
    end

    def names_path
      File.join(compact_index_dir, "names")
    end

    def info_path(name)
      File.join(compact_index_dir, "info", name)
    end

    def reindex
      FileUtils.mkdir_p(File.join(compact_index_dir, "info"))
      full_build(current_versions)
    end

  private

    # name => GemVersionCollection, name-sorted; versions version-sorted.
    def current_versions
      GemVersionCollection.from_specs_index(@data_dir).by_name.to_h
    end

    def full_build(current)
      gems = current.map do |name, versions|
        info_body = write_info(name, versions)
        light_versions = versions.map do |version|
          CompactIndex::GemVersion.new(version.number.to_s, version.platform,
                                       nil, Digest::MD5.hexdigest(info_body))
        end
        CompactIndex::Gem.new(name, light_versions)
      end
      write_versions_list(gems)
      write_names(current.keys)
    end

    def write_versions_list(gems)
      # VersionsFile#create writes in place; render to a temp path and
      # publish atomically like every other file we serve.
      Dir.mktmpdir("compact", @data_dir) do |dir|
        tmp_path = File.join(dir, "versions.list")
        CompactIndex::VersionsFile.new(tmp_path).create(gems, Time.now.utc.iso8601)
        atomic_write(versions_path, File.read(tmp_path))
      end
    end

    # Renders and writes info/NAME; returns the exact bytes written so
    # callers can hash them for the corresponding versions.list line.
    def write_info(name, versions)
      body = CompactIndex.info(info_versions(versions))
      atomic_write(info_path(name), body)
      body
    end

    def write_names(names)
      atomic_write(names_path, CompactIndex.names(names.sort))
    end

    def info_versions(versions)
      versions.map do |version|
        spec = load_spec(version)
        next unless spec
        CompactIndex::GemVersion.new(
          version.number.to_s,
          version.platform,
          gem_checksum(version),
          nil,
          info_dependencies(spec),
          requirement_string(spec.required_ruby_version),
          requirement_string(spec.required_rubygems_version)
        )
      end.compact
    end

    def info_dependencies(spec)
      spec.dependencies.
        select { |dep| dep.type == :runtime }.
        map    { |dep| [dep.name.is_a?(Array) ? dep.name.first : dep.name, dep.requirement.to_s] }.
        sort_by(&:first).
        map    { |name, requirement| CompactIndex::Dependency.new(name, requirement, nil, nil) }
    end

    def requirement_string(requirement)
      requirement&.to_s
    end

    def load_spec(version)
      spec_file = File.join(@data_dir, "quick", "Marshal.#{Gem.marshal_version}",
                            "#{version.gemfile_name}.gemspec.rz")
      return unless File.exist?(spec_file)
      Marshal.load(Gem::Util.inflate(Gem.read_binary(spec_file)))
    end

    def gem_checksum(version)
      Digest::SHA256.file(File.join(@data_dir, "gems", "#{version.gemfile_name}.gem")).hexdigest
    end

    def atomic_write(file_name, contents)
      temp_file = Tempfile.new(".compact", compact_index_dir)
      temp_file.binmode
      temp_file.write(contents)
      temp_file.close
      File.rename(temp_file.path, file_name)
    end
  end

end
