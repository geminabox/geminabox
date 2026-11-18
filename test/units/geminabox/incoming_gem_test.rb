require_relative '../../test_helper'
module Geminabox
  class IncomingGemTest < Minitest::Test

    test "#new" do
      assert_raises ArgumentError do
        Geminabox::IncomingGem.new("NOT AN IO :(")
      end
    end

    test "#valid?" do
      subject = Geminabox::IncomingGem.new(StringIO.new('NOT A GEM'))
      refute subject.valid?

      file = File.open(GemFactory.gem_file(:example))
      subject = Geminabox::IncomingGem.new(file)
      assert subject.valid?
    end

    test "#valid? rejects a gem name that is not a valid RubyGems name" do
      ["../../evil", "a/b", "a\\b"].each do |bad_name|
        spec = Gem::Specification.new do |s|
          s.name = bad_name
          s.version = "1.0.0"
          s.summary = "x"
          s.authors = ["x"]
        end
        Dir.mktmpdir do |dir|
          path = File.join(dir, "crafted.gem")
          silence { Gem::Package.build(spec, true, false, path) }
          subject = File.open(path, "rb") { |f| Geminabox::IncomingGem.new(f) }

          refute subject.valid?, "expected #{bad_name.inspect} to be rejected"
        end
      end
    end

    test "#valid? rejects a version that cannot be loaded back from the index" do
      subject = crafted_gem do |s|
        bad = Gem::Version.allocate
        bad.instance_variable_set(:@version, "1.0 x 2")
        s.instance_variable_set(:@version, bad)
      end

      refute subject.valid?
    end

    test "#valid? rejects a version carrying whitespace that Gem::Version.new would have stripped" do
      ["1.0.0\n", "  1.0.0  ", ""].each do |raw|
        subject = crafted_gem do |s|
          bad = Gem::Version.allocate
          bad.instance_variable_set(:@version, raw)
          s.instance_variable_set(:@version, bad)
        end

        refute subject.valid?, "expected version #{raw.inspect} to be rejected"
      end
    end

    test "#valid? accepts prerelease versions" do
      %w[1.0.0.pre 1.0.0-rc1 2.0.0.beta.2 0.0.1a].each do |version|
        subject = crafted_gem { |s| s.version = version }

        assert subject.valid?, "expected version #{version.inspect} to be accepted"
      end
    end

    test "#valid? rejects a platform containing a compact-index separator" do
      subject = crafted_gem { |s| s.platform = "x86,a-linux" }

      refute subject.valid?
    end

    test "#valid? rejects a malformed required_ruby_version or required_rubygems_version" do
      bad = Gem::Version.allocate
      bad.instance_variable_set(:@version, "1|x\ny")
      [
        ->(s) { s.required_ruby_version.instance_variable_set(:@requirements, [[">=", bad]]) },
        ->(s) { s.required_rubygems_version.instance_variable_set(:@requirements, [["|", Gem::Version.new("1")]]) }
      ].each_with_index do |mutate, i|
        subject = crafted_gem { |s| mutate.call(s) }

        refute subject.valid?, "expected case #{i} to be rejected"
      end
    end

    test "#valid? accepts ordinary required_ruby_version and required_rubygems_version" do
      subject = crafted_gem do |s|
        s.required_ruby_version = ">= 3.0"
        s.required_rubygems_version = ">= 3.2.3"
      end

      assert subject.valid?
    end

    test "#valid? rejects a platform the index would record under a different filename" do
      %w[i686-linux mswin32 jruby].each do |platform|
        subject = crafted_gem { |s| s.platform = platform }

        refute subject.valid?, "expected platform #{platform.inspect} to be rejected"
      end
    end

    test "#valid? accepts canonical platforms" do
      %w[java x86_64-linux x86_64-linux-musl arm64-darwin x64-mingw-ucrt universal-java-11].each do |platform|
        subject = crafted_gem { |s| s.platform = platform }

        assert subject.valid?, "expected platform #{platform.inspect} to be accepted"
      end
    end

    test "#valid? rejects a dependency name that is not a valid RubyGems name" do
      ["rack\n2.0.0 |checksum:x", "a|b", "a,b", "a:b", "../x"].each do |bad_name|
        subject = crafted_gem do |s|
          s.add_dependency "rack"
          s.dependencies.first.instance_variable_set(:@name, bad_name)
        end

        refute subject.valid?, "expected dependency #{bad_name.inspect} to be rejected"
      end
    end

    test "#valid? accepts the legacy array-wrapped dependency name the compact indexer unwraps" do
      subject = crafted_gem do |s|
        s.add_dependency "rack"
        s.dependencies.first.instance_variable_set(:@name, ["rack"])
      end

      assert_equal [["rack"]], subject.spec.dependencies.map(&:name)
      assert subject.valid?
    end

    test "#valid? rejects a development dependency with an invalid name" do
      subject = crafted_gem do |s|
        s.add_development_dependency "rake"
        s.dependencies.first.instance_variable_set(:@name, "rake\nx")
      end

      refute subject.valid?
    end

    test "#valid? rejects a dependency requirement that cannot be parsed" do
      subject = crafted_gem do |s|
        s.add_dependency "rack"
        bad = Gem::Version.allocate
        bad.instance_variable_set(:@version, "1|x\ny")
        s.dependencies.first.requirement.instance_variable_set(:@requirements, [[">=", bad]])
      end

      refute subject.valid?
    end

    test "#valid? rejects a dependency requirement with an unknown operator" do
      subject = crafted_gem do |s|
        s.add_dependency "rack"
        s.dependencies.first.requirement.instance_variable_set(:@requirements, [["|", Gem::Version.new("1")]])
      end

      refute subject.valid?
    end

    test "#valid? accepts ordinary dependencies" do
      subject = crafted_gem do |s|
        s.add_dependency "rack", ">= 2.0", "< 4"
        s.add_dependency "json", "~> 2.7"
        s.add_development_dependency "minitest"
      end

      assert subject.valid?
    end

    test "#spec" do
      file = File.open(GemFactory.gem_file(:example))
      subject = Geminabox::IncomingGem.new(file)

      assert_instance_of Gem::Specification, subject.spec
    end

    test "#name" do
      file = File.open(GemFactory.gem_file(:example))
      subject = Geminabox::IncomingGem.new(file)

      assert_equal "example-1.0.0.gem", subject.name
    end

    test "#name for platform dependent gem" do
      file = File.open(GemFactory.gem_file(:example, :platform => "x86_64-linux"))
      subject = Geminabox::IncomingGem.new(file)

      assert_equal "example-1.0.0-x86_64-linux.gem", subject.name
    end

    test "#dest_filename" do
      file = File.open(GemFactory.gem_file(:example))
      subject = Geminabox::IncomingGem.new(file, "/root/path")

      assert_equal '/root/path/gems/example-1.0.0.gem', subject.dest_filename
    end

    test "#hexdigest" do
      file_name = GemFactory.gem_file(:example)
      File.open(file_name) do |file|
        subject = Geminabox::IncomingGem.new(file)

        assert_equal Digest::SHA1.hexdigest(File.binread(file_name)), subject.hexdigest
      end
    end

    private

    # A client can write any spec into the archive; skip_validation and
    # instance_variable_set stand in for a hand-crafted metadata.gz.
    def crafted_gem
      spec = Gem::Specification.new do |s|
        s.name = "crafted"
        s.version = "1.0.0"
        s.summary = "x"
        s.authors = ["x"]
        s.files = []
      end
      yield spec
      Dir.mktmpdir do |dir|
        path = File.join(dir, "crafted.gem")
        silence { Gem::Package.build(spec, true, false, path) }
        File.open(path, "rb") { |f| Geminabox::IncomingGem.new(f) }
      end
    end

  end
end
