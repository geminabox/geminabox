require_relative '../../test_helper'

module WithTmpReadonly
  def setup
    super

    FileUtils.mkdir File.join(Dir.tmpdir, 'read_only')
    FileUtils.chmod 0444, File.join(Dir.tmpdir, 'read_only')
  end

  def teardown
    super

    FileUtils.rmdir File.join(Dir.tmpdir, 'read_only')
  end
end

class InvalidDataDirTest < Geminabox::TestCase
  data File::NULL

  test "report the error back to the user" do
    assert_match %r{Please ensure /dev/null is a directory.}, geminabox_push(gem_file(:example))
  end
end

class UnwritableDataDirTest < Geminabox::TestCase
  include WithTmpReadonly

  data File.join(Dir.tmpdir, 'read_only')

  test "report the error back to the user" do
    assert_match(/Please ensure #{File.join(Dir.tmpdir, 'read_only')} is writable by the geminabox web server./, geminabox_push(gem_file(:example)))
  end
end

class UnwritableUncreatableDataDirTest < Geminabox::TestCase
  include WithTmpReadonly

  data File.join(Dir.tmpdir, 'read_only', 'geminabox-fail')

  test "report the error back to the user" do
    assert_match(/Could not create #{File.join(Dir.tmpdir, 'read_only', 'geminabox-fail')}/, geminabox_push(gem_file(:example)))
  end
end

class WritableNoneExistentDataDirTest < Geminabox::TestCase
  data "#{data}/more/layers/of/dirs"

  test "create the data dir" do
    FileUtils.rm_rf(config.data)
    assert_can_push
  end
end
