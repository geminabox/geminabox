$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "lib")))
require "geminabox"

Geminabox.data = '/var/geminabox'

run Geminabox::Server
