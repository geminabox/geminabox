module Geminabox
  class GemListMerge
    attr_accessor :list

    IGNORE_DEPENDENCIES = 0..-2

    def self.from(*lists)
      lists.map{|list| new(list)}.inject(:merge)
    end

    def initialize(list)
      @list = list
    end

    def merge(other)
      merged = (list + other.list)
      merged.uniq! {|val| val.values[IGNORE_DEPENDENCIES] }
      merged.sort_by! {|x| x.values[IGNORE_DEPENDENCIES] }
      merged
    end

  end
end
