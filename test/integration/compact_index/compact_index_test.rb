require_relative '../../test_helper'
require 'tmpdir'

class CompactIndexIntegrationTest < Geminabox::TestCase
  test "bundler resolves and updates via the compact index" do
    assert_can_push(:a, deps: [[:b, ">= 0"]])
    assert_can_push(:b)

    Dir.mktmpdir do |dir|
      gemfile = File.join(dir, "Gemfile")
      File.write(gemfile, <<~GEMFILE)
        source "#{url_for("/")}"
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

protected

  def bundle(dir, command)
    output = without_bundler do
      execute("cd #{dir} && env HOME=#{dir} BUNDLE_PATH=#{dir}/vendor " \
              "bundle #{command} --verbose 2>&1")
    end
    assert $?.success?, "bundle #{command} failed:\n#{output}"
    output
  end
end
