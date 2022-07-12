# frozen_string_literal: true

require "fileutils"

module Geminabox
  class RemoteCache
    attr_reader :cache_path, :temp_dir, :gems_dir, :info_dir

    def initialize
      root = Pathname.new(File.expand_path(Geminabox.data))
      @cache_path = root / 'remote_cache'
      @gems_dir = @cache_path / 'gems'
      @info_dir = @cache_path / 'info'
      @temp_dir = root / '_temp'
      ensure_dirs_exist!
    end

    def flush(file_path)
      FileUtils.rm_f(cache_path + file_path)
    end

    def flush_all
      FileUtils.rm_rf(cache_path)
      ensure_dirs_exist!
    end

    def cache(file_path)
      path = cache_path + file_path
      write(path, yield) unless path.exist?
      path
    end

    def md5(file_path)
      data = read(file_path)
      return nil unless data

      Digest::MD5.hexdigest(data)
    end

    def read(file_path)
      File.binread(cache_path + file_path)
    rescue Errno::ENOENT
      nil
    end

    def store(file_path, data)
      write(cache_path + file_path, data) unless data.nil?
      data
    end

    private

    def ensure_dirs_exist!
      FileUtils.mkdir_p(info_dir)
      FileUtils.mkdir_p(gems_dir)
      FileUtils.mkdir_p(temp_dir)
    end

    def write(path, data)
      temp_file = Tempfile.new("remote-cache-upload", temp_dir)
      temp_file.binmode
      File.binwrite(temp_file, data)
      temp_file.close
      File.chmod(Geminabox.gem_permissions, temp_file.path)
      File.rename(temp_file.path, cache_path / path)
    end
  end
end
