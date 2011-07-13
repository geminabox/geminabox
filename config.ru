$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "lib")))
require "geminabox"

Rack::Handler::WEBrick.run Geminabox, :Port => 9494
