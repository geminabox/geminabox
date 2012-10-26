require 'geminabox/gem_version'

class Geminabox::GemVersionCollection
  include Enumerable

  def size
    @gems.size
  end

  attr_reader :gems

  def initialize(initial_gems=[])
    @gems = []
    initial_gems.each { |gemdef| self << gemdef }
    sort!
  end

  def <<(version_or_def)
    version = if version_or_def.is_a?(Geminabox::GemVersion)
                version_or_def
              else
                Geminabox::GemVersion.new(*version_or_def)
              end

    @gems << version
  end

  def oldest
    @gems.first
  end

  def newest
    @gems.last
  end

  def |(other)
    self.class.new(self.gems | other.gems)
  end

  def each(&block)
    @gems.each(&block)
  end

  def by_name
    grouped = @gems.inject(hash_of_collections) do |grouped, gem|
      grouped[gem.name] << gem
      grouped
    end.sort_by{|name, gems| name.downcase }

    if block_given?
      grouped.each(&Proc.new)
    else
      grouped
    end
  end

  def sort!
    @gems.sort!
  end

  private
  def hash_of_collections
    Hash.new { |h,k| h[k] = self.class.new }
  end
end
