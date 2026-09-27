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

  end
end
