
module Geminabox
  module Proxy
    class Splicer < FileHandler
      
      def self.make(file_name)
        splicer = new(file_name)
        splicer.create
        splicer
      end

      def create
        File.open(splice_path, 'w'){|f| f.write(new_content)}
      end

      def new_content
        if local_file_exists?
          merge_content
        else
          remote_content
        end
      end

      def splice_path
        proxy_path
      end

      def splice_folder_path
        proxy_folder_path
      end

      def splice_file_exists?
        file_exists? splice_path
      end

      def merge_content
        if gzip?
          merge_gziped_content
        else
          merge_text_content
        end
      end

      def gzip?
        /\.gz$/ =~ file_name
      end

      private
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
end
