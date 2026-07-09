require_relative '../test_helper'
require 'minitest'
require 'rack/test'
require 'nokogiri'

# master.js binds its delete-confirmation dialog to "form.delete-form".
# These tests pin the markup contract: every page with a delete button must
# load master.js and render its delete forms so that selector matches,
# otherwise the button submits with no confirmation.
class DeleteConfirmationMarkupTest < Minitest::Test
  include Rack::Test::Methods

  CONFIRMED_FORM_SELECTOR = "form.delete-form"

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

  test "index page loads master.js" do
    get "/"
    assert last_response.ok?
    refute_empty doc.css("script[src*='master.js']")
  end

  test "index page delete forms match the confirmation selector" do
    get "/"
    assert last_response.ok?
    forms = doc.css(CONFIRMED_FORM_SELECTOR)
    refute_empty forms
    assert forms.all? { |form| form.css("button[type=submit]").any? }
  end

  test "gem page loads master.js" do
    get "/gems/foo"
    assert last_response.ok?
    refute_empty doc.css("script[src*='master.js']")
  end

  test "gem page delete forms match the confirmation selector" do
    get "/gems/foo"
    assert last_response.ok?
    forms = doc.css(CONFIRMED_FORM_SELECTOR)
    refute_empty forms
    assert forms.all? { |form| form.css("button[type=submit]").any? }
  end
end
