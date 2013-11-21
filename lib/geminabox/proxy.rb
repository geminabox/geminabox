
module Geminabox
  module Proxy
    def self.proxy_path(file)
      File.join File.dirname(__FILE__), 'proxy', file
    end

    autoload :Hostess,      proxy_path('hostess')
    autoload :FileHandler,  proxy_path('file_handler')
    autoload :Splicer,      proxy_path('splicer')
    autoload :Copier,       proxy_path('copier')
  end
end
