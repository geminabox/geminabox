require_relative '../test_helper'
require 'minitest'
require 'rack/test'
require 'nokogiri'

# Each gem card on the index carries a named anchor (id="gem_<name>") on its
# header, plus a .permalink link pointing at that same fragment, so a gem's
# block can be linked directly.
class GemPermalinkMarkupTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    clean_data_dir
    inject_gems do |builder|
      builder.gem "foo", version: "1.2.3"
      builder.gem "bar", version: "0.1.0"
    end
  end

  def app
    Geminabox::Server
  end

  def doc
    Nokogiri::HTML(last_response.body)
  end

  test "each gem card header has a matching named anchor and permalink" do
    get "/"

    cards = doc.css("ul.gemlist li.gem-card")
    refute_empty cards, "no gem cards on the index"

    cards.each do |card|
      header = card.at_css(".card-header")
      refute_nil header, "gem card missing a header"

      anchor_id = header["id"]
      refute_nil anchor_id, "card header missing an id anchor"
      assert_match(/\Agem_/, anchor_id, "anchor id should be namespaced with gem_")

      permalink = header.at_css("a.permalink")
      refute_nil permalink, "card header missing a permalink link"
      assert_equal "##{anchor_id}", permalink["href"],
                   "permalink href should point at its own card anchor"
    end
  end

  test "permalink anchors are unique per gem" do
    get "/"

    ids = doc.css("ul.gemlist li.gem-card .card-header").map { |h| h["id"] }
    assert_equal ids, ids.uniq, "gem anchor ids should be unique"
    assert_includes ids, "gem_foo"
    assert_includes ids, "gem_bar"
  end
end
