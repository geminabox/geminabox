module Geminabox
  class GemFinder
    # find specify gem with from disk (doesn't decode spec file)
    def self.find_by_name(name)
      gem_versions = []
      Dir.glob(File.join(Server.settings.data, "gems", "#{name}-*.gem")) do |filename|
        case filename
        when /#{name}-([^\-]+)-([^\-]+)\.gem$/
          gem_versions << Geminabox::GemVersion.new(name, Regexp.last_match[1], Regexp.last_match[2])
        when /#{name}-([^\-]+)\.gem$/
          gem_versions << Geminabox::GemVersion.new(name, Regexp.last_match[1], "ruby")
        end
      end
      gem_versions
    end
  end
end
