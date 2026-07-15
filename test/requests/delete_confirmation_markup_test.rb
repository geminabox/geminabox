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

  CONFIRMED_FORM_SELECTOR = "form.delete-form".freeze

  def setup
    clean_data_dir
    inject_gems do |builder|
      builder.gem "foo", version: "1.2.3"
      builder.gem "bar", version: "2.0.0", platform: "java"
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
    assert(forms.all? { |form| form.css("button[type=submit]").any? })
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
    assert(forms.all? { |form| form.css("button[type=submit]").any? })
  end

  test "delete forms carry the attributes the dialog names the gem with" do
    get "/"
    foo = doc.css("#{CONFIRMED_FORM_SELECTOR}[data-gem-name=foo]").first
    assert foo
    assert_equal "1.2.3", foo["data-version"]
    assert_equal "ruby", foo["data-platform"]

    bar = doc.css("#{CONFIRMED_FORM_SELECTOR}[data-gem-name=bar]").first
    assert bar
    assert_equal "2.0.0", bar["data-version"]
    assert_equal "java", bar["data-platform"]
  end

  test "gem page delete forms carry the same data attributes" do
    get "/gems/bar"
    form = doc.css("#{CONFIRMED_FORM_SELECTOR}[data-gem-name=bar]").first
    assert form
    assert_equal "2.0.0", form["data-version"]
    assert_equal "java", form["data-platform"]
  end

  test "pages with delete forms render the confirmation dialog skeleton" do
    ["/", "/gems/foo"].each do |path|
      get path
      dialog = doc.css("dialog#delete-confirm")
      refute_empty dialog
      refute_empty dialog.css("button.cancel")
      refute_empty dialog.css("button.danger")
    end
  end

  test "no dialog is rendered when deletion is disabled" do
    Geminabox.allow_delete = false
    get "/"
    assert_empty doc.css("dialog#delete-confirm")
  ensure
    Geminabox.allow_delete = true
  end
end
