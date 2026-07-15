require_relative '../test_helper'
require_relative '../test_support/gem_factory'
require 'rubygems/package'

# GemFactory caches built .gem files by name-version-platform so a run does not
# rebuild the same fixture repeatedly. The dependencies are baked into the gem
# but are not part of the cache key, so a gem built once must not be handed back
# to a later caller that asked for the same name/version with different deps.
class GemFactoryTest < Minitest::Test
  DIR = File.join(Dir.tmpdir, "geminabox-gem-factory-test")

  def setup
    FileUtils.rm_rf(DIR)
  end

  def factory
    @factory ||= GemFactory.new(DIR)
  end

  def runtime_deps(path)
    Gem::Package.new(path.to_s).spec.dependencies
                .select { |dep| dep.type == :runtime }
                .map { |dep| [dep.name, dep.requirement.to_s] }
  end

  test "does not serve a cached gem built with different dependencies" do
    # An earlier caller builds a-2.0.0 with no dependencies (as the compact
    # index integration test does).
    depless = factory.gem(:a, version: "2.0.0")
    assert_equal [], runtime_deps(depless)

    # A later caller asks for the same name/version but with a dependency (as
    # the dependency-API tests do). The name-version cache must not hand back
    # the depless build.
    with_dep = factory.gem(:a, version: "2.0.0", deps: [[:b, ">= 1"]])
    assert_equal [["b", ">= 1"]], runtime_deps(with_dep),
                 "GemFactory reused a cached a-2.0.0 that lacked the requested dependency"
  end

  test "reuses the cache for an identical request" do
    path = factory.gem(:a, version: "1.0.0", deps: [[:b, ">= 0"]])
    File.utime(0, 0, path) # stamp a sentinel mtime a rebuild would overwrite
    again = factory.gem(:a, version: "1.0.0", deps: [[:b, ">= 0"]])
    assert_equal path, again
    assert_equal Time.at(0), File.mtime(again),
                 "an identical request must reuse the cached gem, not rebuild it"
  end
end
