

module Geminabox
  module Proxy
    class Copier < FileHandler

      def self.copy(file_name)
        copier = new(file_name)
        copier.get_file
        copier
      end

      def get_file
        return true if proxy_file_exists?
        return copy_local if local_file_exists?
        get_remote
      end

      def copy_local
        FileUtils.cp local_path, proxy_path
      end

      def get_remote
        File.open(proxy_path, 'w'){|f| f.write(remote_content)}
      end

    end
  end
end
