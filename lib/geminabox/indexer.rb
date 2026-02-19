# frozen_string_literal: true

require 'geminabox'

module Geminabox::Indexer
  def self.updated_gemspecs(indexer)
    specs_mtime = File.stat(indexer.dest_specs_index).mtime rescue Time.at(0)
    newest_mtime = Time.at 0

    updated_gems = indexer.gem_file_list.select do |gem|
      gem_mtime = File.stat(gem).mtime
      newest_mtime = gem_mtime if gem_mtime > newest_mtime
      gem_mtime >= specs_mtime
    end

    indexer.map_gems_to_specs updated_gems
  end
end
