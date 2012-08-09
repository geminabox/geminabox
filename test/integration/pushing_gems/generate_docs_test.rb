require 'test_helper'

class DisableDocGenerationTest < Geminabox::TestCase
  document_gems false

  test "does not generate docs when document_gems set to false" do
    geminabox_push(gem_file(:example))
    refute(Dir.exist?("#{Geminabox.public_folder}/docs/example-1.0.0"))
  end
end

class GenerateDocsTest < Geminabox::TestCase
  test "generates docs by default" do
    geminabox_push(gem_file(:example))
    assert(Dir.exist?("#{Geminabox.public_folder}/docs/example-1.0.0"))
  end
end
