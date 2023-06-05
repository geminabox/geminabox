module Geminabox
  class CompactIndexer

    include Gem::UserInteraction

    module PathMethods
      def index_path
        File.expand_path(File.join(datadir, 'compact_index'))
      end

      def versions_path
        File.join(index_path, 'versions')
      end

      def merged_versions_path
        File.join(index_path, 'merged_versions')
      end

      def info_path
        File.join(index_path, 'info')
      end

      def info_name_path(name)
        File.join(info_path, name)
      end
    end

    class Paths
      include PathMethods

      attr_reader :datadir

      def initialize(datadir)
        @datadir = datadir
      end
    end

    attr_reader :datadir

    def initialize
      @datadir = Geminabox.data
    end

    include PathMethods

    def activate!
      FileUtils.mkdir_p(info_path)
    end

    def active?
      File.exist?(info_path)
    end

    def clear_index
      FileUtils.rm_rf(index_path)
    end

    def fetch_info(name)
      path = info_name_path(name)
      File.binread(path) if File.exist?(path)
    end

    def fetch_versions
      path = versions_path
      File.binread(path) if File.exist?(path)
    end

    def reindex(specs = nil)
      FileUtils.mkdir_p(info_path)

      if specs && File.exist?(versions_path)
        Gem.time("Compact index incremental reindex") do
          incremental_reindex(specs)
        end
        return
      end

      Gem.time("Compact index full rebuild") do
        full_reindex
      end
    end

    def yank(spec)
      with_tmp_dir do |dest_paths|
        name = spec.name
        info = DependencyInfo.new(name)
        data = fetch_info(name)
        return [] unless data

        info.content = data
        info.remove_gem_spec(spec)

        prepare_files_for_yank(name, info, dest_paths)
      end
    end

    private

    def incremental_reindex(gem_specs)
      with_tmp_dir do |dest_paths|
        version_info = VersionInfo.new
        version_info.load_versions(versions_path)

        updated_files = prepare_info_files(gem_specs, dest_paths, version_info)

        file_path = dest_paths.versions_path
        updated_files << [file_path, versions_path]
        version_info.write(file_path)

        updated_files
      end
    end

    def prepare_info_files(gem_specs, dest_paths, version_info)
      updated_files = []
      gem_specs.group_by(&:name).each do |name, specs|
        info = DependencyInfo.new(name)
        data = fetch_info(name)
        info.content = data if data

        specs.each do |spec|
          gem_version = GemVersion.from_spec(spec)
          checksum = Specs.checksum_for_version(gem_version)
          info.add_gem_spec_and_gem_checksum(spec, checksum)
        end

        file_path = dest_paths.info_name_path(name)
        updated_files << [file_path, info_name_path(name)]
        File.binwrite(file_path, info.content)
        version_info.update_gem_versions(info)
      end
      updated_files
    end

    def all_specs
      Geminabox::GemVersionCollection.new(Specs.all_gems)
    end

    def full_reindex
      clear_index
      activate!

      version_info = VersionInfo.new

      specs = all_specs.by_name.to_h
      count = specs.size + 1
      n = Geminabox.workers

      title = "Building #{count} compact index files"
      progressbar_options = Gem::DefaultUserInteraction.ui.outs.tty? && n > 1 && {
        title: title,
        total: count,
        format: '%t %b',
        progress_mark: '.'
      }
      say title unless progressbar_options

      fork_type = { in_processes: n }
      fork_type = { in_threads: n } if RUBY_PLATFORM == 'x64-mingw32'

      infos = Parallel.map(specs, progress: progressbar_options, **fork_type) do |name, versions|
        info = dependency_info(versions)
        file = info_name_path(name)
        File.binwrite(file, info.content)
        info
      end

      infos.each { |info| version_info.update_gem_versions(info) }
      version_info.write(versions_path)
    end

    def dependency_info(gem)
      name, versions = gem.by_name.first
      info = DependencyInfo.new(name)
      versions.each do |version|
        spec = Specs.spec_for_version(version)
        checksum = Specs.checksum_for_version(version) if spec
        info.add_gem_spec_and_gem_checksum(spec, checksum) if checksum
      end
      info
    end

    def with_tmp_dir
      directory = Dir.mktmpdir("geminabox-compact-index")
      dest_paths = Paths.new(directory)
      FileUtils.mkdir_p(dest_paths.info_path)
      updated_files = yield dest_paths
      updated_files.each do |src, dest|
        if src
          FileUtils.mv(src, dest)
        else
          FileUtils.rm(dest)
        end
      end
    ensure
      FileUtils.rm_rf(directory)
    end

    def prepare_files_for_yank(name, info, dest_paths)
      updated_files = []
      file_path = info.versions.empty? ? nil : dest_paths.info_name_path(name)
      updated_files << [file_path, info_name_path(name)]
      File.binwrite(file_path, info.content) if file_path

      version_info = VersionInfo.new
      version_info.load_versions(versions_path)
      version_info.update_gem_versions(info)

      file_path = dest_paths.versions_path
      updated_files << [file_path, versions_path]
      version_info.write(file_path)

      updated_files
    end

  end
end
