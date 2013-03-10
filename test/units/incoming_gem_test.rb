require 'test_helper'

class IncomingGemTest < MiniTest::Unit::TestCase

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
    file = File.open(file_name, 'rb')
    subject = Geminabox::IncomingGem.new(file)

    File.open(file_name, 'rb') do |compare_file|
      assert_equal Digest::SHA1.hexdigest(compare_file.read), subject.hexdigest
    end

  end

end
