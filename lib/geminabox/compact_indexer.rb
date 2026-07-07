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
      known = known_versions
      current = current_versions
      if known
        reconcile(known, current)
      else
        full_build(current)
      end
    end

    private

    # Cumulative state recorded in versions.list. Returns nil when the file
    # is missing or unparseable, which triggers a from-scratch build.
    # Otherwise returns [state, checksums]:
    #   state     => name => array of version_and_platform strings still
    #                live (yanks subtracted).
    #   checksums => name => the last MD5 recorded for that name, so a
    #                content-only change can be detected against it.
    def known_versions
      return nil unless File.exist?(versions_path)

      lines = File.read(versions_path).split("\n")
      separator = lines.index("---")
      return nil unless separator

      state = Hash.new { |hash, key| hash[key] = [] }
      checksums = {}
      lines.drop(separator + 1).each do |line|
        name, versions, checksum = line.split
        return nil unless name && versions && checksum

        versions.split(",").each do |entry|
          if entry.start_with?("-")
            state[name].delete(entry[1..])
          else
            state[name] << entry
          end
        end
        checksums[name] = checksum
      end
      [state, checksums]
    end

    def reconcile(known, current)
      known_state, known_checksums = known
      additions = +""

      current.each do |name, versions|
        current_ids = versions.map(&:number_and_platform)
        added = current_ids - known_state.fetch(name, [])
        removed = known_state.fetch(name, []) - current_ids
        if added.empty? && removed.empty?
          line = refresh_line(name, versions, current_ids, known_checksums[name])
          additions << line if line
          next
        end
        info_body = write_info(name, versions)
        entries = added + removed.map { |id| "-#{id}" }
        additions << version_line(name, entries, info_body)
      end

      (known_state.keys - current.keys).each do |name|
        removed = known_state[name]
        next if removed.empty?

        info_body = CompactIndex.info([])
        atomic_write(info_path(name), info_body)
        additions << version_line(name, removed.map { |id| "-#{id}" }, info_body)
      end

      if additions.empty?
        # Self-heal a names file deleted out from under an intact
        # versions.list, so /names does not 404 forever.
        write_names(current.keys) unless File.exist?(names_path)
        return
      end
      atomic_write(versions_path, File.read(versions_path) + additions)
      write_names(current.keys)
    end

    # A same-version replacement (allow_replace / `gem inabox -o`) changes the
    # .gem contents without changing the version identity set, so the identity
    # diff is empty. Detect that here and, when the freshly rendered info body
    # differs from what versions.list last recorded, emit a "touch" line that
    # yanks and re-adds every current version in one entry. Bundler processes
    # entries in order, so delete-then-add leaves the version set intact while
    # the trailing MD5 (last checksum wins) points at the new info bytes.
    # Returns nil when nothing needs to change, keeping reconcile idempotent.
    def refresh_line(name, versions, current_ids, known_checksum)
      return unless dirty?(name, versions)

      info_body = write_info(name, versions)
      return if Digest::MD5.hexdigest(info_body) == known_checksum

      entries = current_ids.map { |id| "-#{id}" } + current_ids
      version_line(name, entries, info_body)
    end

    # A gem is content-dirty when its info file is missing, or when any of its
    # stored .gem files is at least as new as the info file. The >= tolerance
    # matches Geminabox::Indexer.updated_gemspecs.
    def dirty?(name, versions)
      info = info_path(name)
      return true unless File.exist?(info)

      info_mtime = File.stat(info).mtime
      versions.any? do |version|
        gem_file = File.join(@data_dir, "gems", "#{version.gemfile_name}.gem")
        File.exist?(gem_file) && File.stat(gem_file).mtime >= info_mtime
      end
    end

    def version_line(name, entries, info_body)
      "#{name} #{entries.join(',')} #{Digest::MD5.hexdigest(info_body)}\n"
    end

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
      spec.dependencies
          .select { |dep| dep.type == :runtime }
          .map { |dep| [dep.name.is_a?(Array) ? dep.name.first : dep.name, dep.requirement.to_s] }
          .sort_by(&:first)
          .map { |name, requirement| CompactIndex::Dependency.new(name, requirement, nil, nil) }
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
      # Tempfile is created 0600; publish the served files world-readable
      # (subject to the process umask) like Gem::Indexer's own output.
      # chmod while the handle is still open -- Tempfile#chmod delegates to
      # the underlying File, which raises once closed.
      temp_file.chmod(0o644 & ~File.umask)
      temp_file.close
      File.rename(temp_file.path, file_name)
    end
  end
end
