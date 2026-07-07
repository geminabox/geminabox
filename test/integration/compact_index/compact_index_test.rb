require_relative '../../test_helper'
require 'tmpdir'

class CompactIndexIntegrationTest < Geminabox::TestCase
  test "bundler resolves and updates via the compact index" do
    assert_can_push(:a, deps: [[:b, ">= 0"]])
    assert_can_push(:b)

    Dir.mktmpdir do |dir|
      gemfile = File.join(dir, "Gemfile")
      File.write(gemfile, <<~GEMFILE)
        source "#{url_for('/')}"
        gem "a"
      GEMFILE

      output = bundle(dir, "install")
      lockfile = File.read(File.join(dir, "Gemfile.lock"))
      assert_match(/^    a \(1\.0\.0\)$/, lockfile)
      assert_match(/^      b$/, lockfile)
      assert_match(%r{HTTP GET http://localhost:\d+/versions}, output,
                   "bundler should fetch the compact index")
      assert_match(%r{HTTP GET http://localhost:\d+/info/a}, output)

      assert_can_push(:a, version: "2.0.0")

      output = bundle(dir, "update a")
      assert_match(/HTTP 206 Partial Content/, output,
                   "second fetch should be a ranged tail append")
      assert_match(/^    a \(2\.0\.0\)$/, File.read(File.join(dir, "Gemfile.lock")))
    end
  end

  test "a same-version replacement is served correctly to a fresh resolver" do
    assert_can_push(:a, deps: [[:b, ">= 0"]])
    assert_can_push(:b)
    assert_can_push(:c)

    # First consumer resolves against the original a (depends on b). This also
    # builds the compact index, so the replacement below exercises reconcile's
    # touch-line path rather than a cold full_build.
    Dir.mktmpdir do |dir|
      write_gemfile(dir)
      bundle(dir, "install")
      lock = File.read(File.join(dir, "Gemfile.lock"))
      assert_match(/^    a \(1\.0\.0\)$/, lock)
      assert_match(/^      b$/, lock, "baseline: a depends on b")
      refute_match(/^      c$/, lock)
    end

    # Replace the stored a-1.0.0.gem in place with a build that depends on c
    # instead of b: same version identity, different content. GemFactory skips
    # building when the target exists, so build it in a throwaway dir and push
    # with --overwrite (bypasses check_replacement_status).
    Dir.mktmpdir do |other|
      replacement = GemFactory.new(other).gem("a", deps: { c: ">= 0" })
      push_overwrite(replacement)
    end

    # A fresh consumer with no prior lock must see the touch-line-refreshed
    # info/a: the new dependency c AND a checksum matching the replaced .gem.
    # If reconcile had left info/a stale, resolution would surface b, or the
    # stale checksum would trip Bundler's download verification.
    Dir.mktmpdir do |dir|
      write_gemfile(dir)
      output = bundle(dir, "install")
      lock = File.read(File.join(dir, "Gemfile.lock"))
      assert_match(/^    a \(1\.0\.0\)$/, lock, "same version identity")
      assert_match(/^      c$/, lock, "a's dependency must now be c")
      assert_match(/^    c \(1\.0\.0\)$/, lock)
      refute_match(/^      b$/, lock, "a's old dependency b must be gone")
      assert_match(%r{HTTP GET http://localhost:\d+/info/a}, output)
    end
  end

  protected

  def write_gemfile(dir)
    File.write(File.join(dir, "Gemfile"), <<~GEMFILE)
      source "#{url_for('/')}"
      gem "a"
    GEMFILE
  end

  def bundle(dir, command)
    output = without_bundler do
      execute("cd #{dir} && env HOME=#{dir} BUNDLE_PATH=#{dir}/vendor " \
              "bundle #{command} --verbose 2>&1")
    end
    assert $?.success?, "bundle #{command} failed:\n#{output}"
    output
  end

  def push_overwrite(gemfile)
    Geminabox::TestCase.setup_fake_home!
    command = "GEM_HOME=#{FAKE_HOME} gem inabox #{gemfile} --overwrite " \
              "-g '#{config.url_with_port(@test_server_port)}' 2>&1"
    output = execute(command)
    assert_match(/received and indexed/, output, "overwrite push failed:\n#{output}")
    output
  end
end
