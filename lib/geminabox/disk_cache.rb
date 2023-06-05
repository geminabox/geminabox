# frozen_string_literal: true

require "fileutils"
module Geminabox
  class Geminabox::DiskCache
    attr_reader :root_path

    def initialize(root_path)
      @root_path = root_path
      ensure_dir_exists!
    end

    def flush_key(key)
      path = path(key_hash(key))
      FileUtils.rm_f(path)
    end

    def flush
      FileUtils.rm_rf(root_path)
      ensure_dir_exists!
    end

    def cache(key)
      key_hash = key_hash(key)
      read(key_hash) || write(key_hash, yield)
    end

    def marshal_cache(key)
      key_hash = key_hash(key)
      marshal_read(key_hash) || marshal_write(key_hash, yield)
    end

  protected

    def ensure_dir_exists!
      FileUtils.mkdir_p(root_path)
    end

    def key_hash(key)
      Digest::MD5.hexdigest(key)
    end

    def path(key_hash)
      File.join(root_path, key_hash)
    end

    def read(key_hash)
      read_int(key_hash) do |path|
        begin
          File.read(path)
        rescue Errno::ENOENT
          # There is a possibility that the file is removed by another process
          # after checking File.exist?. Return nil if the file does not exist.
          nil
        end
      end
    end

    def marshal_read(key_hash)
      read_int(key_hash) do |path|
        begin
          File.open(path) {|fp| Marshal.load(fp) }
        rescue Errno::ENOENT, EOFError
          # There is a possibility that the file is removed by another process.
          # Marshal.load raises EOFError if the file is removed after File.open(path) succeeds.
          # Return nil if the file does not exist.
          nil
        end
      end
    end

    def read_int(key_hash)
      path = path(key_hash)
      yield(path) if File.exist?(path)
    end

    def write(key_hash, value)
      write_int(key_hash) { |f| f << value }
      value
    end

    def marshal_write(key_hash, value)
      write_int(key_hash) { |f| Marshal.dump(value, f) }
      value
    end

    def write_int(key_hash)
      File.open(path(key_hash), 'wb') { |f| yield(f) }.then { @retried = false }
    rescue Errno::ENOENT => e
      raise e if @retried

      # There is a possibility that the directory is removed by another process.
      ensure_dir_exists!
      @retried = true
      retry
    end

  end
end
