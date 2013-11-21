module Geminabox
  class GemListMerge
    attr_accessor :list

    def self.from(*lists)
      lists.map{|list| new(list)}.inject(:merge)
    end

    def initialize(list)
      @list = list
    end

    def merge(other)
      combine_hashes(other).values.flatten.sort do |x, y|
        x.values[ignore_dependencies] <=> y.values[ignore_dependencies]
      end
    end

    def hash
      list.each do |item|
        ensure_symbols_as_keys(item)
        name = item[:name].to_sym
        collection[name] ||= []
        collection[name] << item unless collection[name].include?(item)
      end
      collection
    end

    def collection
      @collection ||= {}
    end

    def combine_hashes(other)
      hash.merge(other.hash) do |key, value, other_value|
        (value + other_value).uniq{|v| v.values[ignore_dependencies]}
      end
    end

    def ignore_dependencies
      0..-2
    end

    def ensure_symbols_as_keys(item)
      item.keys.each do |key|
        next if key.kind_of? Symbol
        item[key.to_sym] = item.delete(key)
      end
    end

  end
end
