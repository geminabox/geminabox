module Geminabox

  class GemStore
    attr_accessor :gem, :overwrite

    def self.create(gem, overwrite = false)
      gem_store = new(gem, overwrite)
      gem_store.save
    end

    def initialize(gem, overwrite = false)
      @gem = gem
      @overwrite = overwrite && overwrite == 'true'
    end

    def save
      ensure_gem_valid
      prepare_data_folders
      check_replacement_status
      write_and_index
    end

    def prepare_data_folders
      ensure_existing_data_folder_compatible
      begin
        FileUtils.mkdir_p(File.join(Geminabox.data, "gems"))
      rescue
        raise GemStoreError.new(
          500,
          "Could not create #{File.expand_path(Geminabox.data)}."
        )
      end
    end

    def check_replacement_status
      if !overwrite and Geminabox::Server.disallow_replace? and File.exist?(gem.dest_filename)
        if existing_file_digest != gem.hexdigest
          raise GemStoreError.new(409, "Updating an existing gem is not permitted.\nYou should either delete the existing version, or change your version number.")
        else
          raise GemStoreError.new(200, "Ignoring upload, you uploaded the same thing previously.\nPlease use -o to overwrite.")
        end
      end
    end

    def ensure_gem_valid
      raise GemStoreError.new(400, "Cannot process gem") unless gem.valid?
    end

    private
    def ensure_existing_data_folder_compatible
      if File.exist? Geminabox.data
        ensure_data_folder_is_directory
        ensure_data_folder_is_writable
      end
    end

    def ensure_data_folder_is_directory
      raise GemStoreError.new(
        500,
        "Please ensure #{File.expand_path(Geminabox.data)} is a directory."
      ) unless File.directory? Geminabox.data
    end

    def ensure_data_folder_is_writable
      raise GemStoreError.new(
        500,
        "Please ensure #{File.expand_path(Geminabox.data)} is writable by the geminabox web server."
      ) unless File.writable? Geminabox.data
    end

    def existing_file_digest
      Digest::SHA1.file(gem.dest_filename).hexdigest
    end

    def write_and_index
      tmpfile = gem.gem_data
      atomic_write(gem.dest_filename) do |f|
        while blk = tmpfile.read(65536)
          f << blk
        end
      end
      Geminabox::Server.reindex
    end

    # based on http://as.rubyonrails.org/classes/File.html
    def atomic_write(file_name)
      temp_dir = File.join(Geminabox.data, "_temp")
      FileUtils.mkdir_p(temp_dir)
      temp_file = Tempfile.new("." + File.basename(file_name), temp_dir)
      temp_file.binmode
      yield temp_file
      temp_file.close
      File.rename(temp_file.path, file_name)
      File.chmod(Geminabox.gem_permissions, file_name)
    end

  end

end
