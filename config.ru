$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "lib")))
require "geminabox"

ENV['RUBYGEMS_PROXY'] ||= 'false'

run Geminabox
