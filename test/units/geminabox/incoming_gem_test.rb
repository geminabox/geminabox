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

      File.open(GemFactory.gem_file(:example)) do |file|
        subject = Geminabox::IncomingGem.new(file)
        assert subject.valid?
      end
    end

    test "#spec" do
      File.open(GemFactory.gem_file(:example)) do |file|
        subject = Geminabox::IncomingGem.new(file)

        assert_instance_of Gem::Specification, subject.spec
      end
    end

    test "#name" do
      File.open(GemFactory.gem_file(:example)) do |file|
        subject = Geminabox::IncomingGem.new(file)

        assert_equal "example-1.0.0.gem", subject.name
      end
    end

    test "#name for platform dependent gem" do
      File.open(GemFactory.gem_file(:example, :platform => "x86_64-linux")) do |file|
        subject = Geminabox::IncomingGem.new(file)

        assert_equal "example-1.0.0-x86_64-linux.gem", subject.name
      end
    end

    test "#dest_filename" do
      File.open(GemFactory.gem_file(:example)) do |file|
        subject = Geminabox::IncomingGem.new(file, "/root/path")

        assert_equal '/root/path/gems/example-1.0.0.gem', subject.dest_filename
      end
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
