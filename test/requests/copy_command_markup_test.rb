require_relative '../test_helper'
require 'minitest'
require 'rack/test'
require 'nokogiri'

# master.js binds copy-to-clipboard behavior to button.copy-command and
# copies the text of the sibling code element inside .version-row.
class CopyCommandMarkupTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
    inject_gems do |builder|
      builder.gem "foo", version: "1.2.3"
    end
  end

  def app
    Geminabox::Server
  end

  def doc
    Nokogiri::HTML(last_response.body)
  end

  test "each version row offers a copy button next to its install command" do
    ["/", "/gems/foo"].each do |path|
      get path
      rows = doc.css(".version-row")
      refute_empty rows, "no version rows on #{path}"
      rows.each do |row|
        refute_empty row.css("button.copy-command"), "row missing copy button on #{path}"
        refute_empty row.css("code"), "row missing command code on #{path}"
      end
    end
  end
end
