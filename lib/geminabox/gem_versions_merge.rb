module Geminabox
  module GemVersionsMerge
    def self.merge(local_gem_list, remote_gem_list, strategy:)
      return local_gem_list unless remote_gem_list

      local_split = local_gem_list.split("\n")
      remote_split = remote_gem_list.split("\n")
      combined = strategy_for(strategy).merge(local_split, remote_split)

      "#{(local_split[0..1] + combined.values).join("\n")}\n"
    end

    def self.strategy_for(strategy)
      case strategy
      when :local_gems_take_precedence_over_remote_gems
        LocalGemsTakePrecedenceOverRemoteGems
      when :remote_gems_take_precedence_over_local_gems
        RemoteGemsTakePrecedenceOverLocalGems
      else
        raise ArgumentError, "Merge strategy must be :local_gems_take_precedence_over_remote_gems (default) or :remote_gems_take_precedence_over_local_gems"
      end
    end

    module Helpers
      def self.gems_hash(source)
        source[2..-1].map { |line| [line[/(^\S+)\s/], line] }.to_h
      end
    end

    module LocalGemsTakePrecedenceOverRemoteGems
      def self.merge(local_split, remote_split)
        Helpers.gems_hash(remote_split).merge(Helpers.gems_hash(local_split))
      end
    end

    module RemoteGemsTakePrecedenceOverLocalGems
      def self.merge(local_split, remote_split)
        Helpers.gems_hash(local_split).merge(Helpers.gems_hash(remote_split))
      end
    end
  end
end
