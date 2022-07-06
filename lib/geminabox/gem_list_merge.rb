# frozen_string_literal: true

require "set"

module Geminabox
  module GemListMerge
    def self.merge(local_gem_list, remote_gem_list)
      local_names = Set.new(local_gem_list.map { |gem| gem[:name] })
      local_gem_list + remote_gem_list.reject { |gem| local_names.include? gem[:name] }
    end
  end
end
