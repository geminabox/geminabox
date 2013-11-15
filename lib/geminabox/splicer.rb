
module Geminabox
  class Splicer
    attr_reader :file_name

    def self.make(file_name)
      splicer = new(file_name)
      splicer.create
      splicer
    end

    def initialize(file_name)
      @file_name = file_name
    end

    def create
      ensure_splice_exists
      File.open(splice_path, 'w'){|f| f.write(new_content)}
    end

    def new_content
      if local_file_exists?
        merge_content
      else
        remote_content
      end
    end

    def local_path
      File.expand_path(file_name, root_path)
    end

    def splice_path
      File.expand_path(file_name, splice_folder_path)
    end

    def splice_folder_path
      File.join(root_path, 'spliced')
    end

    def root_path
      Geminabox.data
    end

    def local_file_exists?
      file_exists? local_path
    end

    def splice_file_exists?
      file_exists? splice_path
    end

    def file_exists?(path)
      File.exists? path
    end

    def remote_content
      HTTPClient.get_content(remote_url).force_encoding("UTF-8")
    end
    
    def local_content
      File.read(local_path).force_encoding("UTF-8")
    end

    def merge_content
      if gzip?
        merge_gziped_content
      else
        merge_text_content
      end
    end

    def remote_url
      "http://rubygems.org/#{file_name}"
    end

    def gzip?
      /\.gz$/ =~ file_name
    end

    private
    def ensure_splice_exists
      create_spliced_folder unless spliced_folder_exists?
    end

    def spliced_folder_exists?
      Dir.exists?(splice_folder_path)
    end

    def create_spliced_folder
      FileUtils.mkdir_p(splice_folder_path)
    end

    def merge_gziped_content
      package(unpackage(local_content) | unpackage(remote_content))
    end

    def unpackage(content)
      Marshal.load(Gem.gunzip(content))
    end

    def package(content)
      Gem.gzip(Marshal.dump(content))
    end

    def merge_text_content
      local_content.to_s + remote_content.to_s
    end
  end
end
