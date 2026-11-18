require_relative '../../test_helper'

class SSLTest < Geminabox::TestCase
  url "https://localhost/"
  ssl true

  # Trusts the test CA through SSL_CERT_FILE, which reaches the client only
  # because it loads the system trust store rather than httpclient's bundle.
  should_push_gem
  # test "s" do
  #   puts url_for("/")
  #   sleep 1000
  # end

  test "refuses to push to a server whose certificate it does not trust" do
    output = geminabox_push(gem_file(:example), { "SSL_CERT_FILE" => nil })

    assert_match(/certificate verify failed/, output)
    refute File.exist?(File.join(config.data, "gems", "example-1.0.0.gem")), "gem must not reach the server"
  end

  test "pushes to an untrusted server only when TLS verification is explicitly skipped, and warns" do
    output = geminabox_push(gem_file(:example), { "SSL_CERT_FILE" => nil, "GEMINABOX_INSECURE_SKIP_TLS_VERIFY" => "1" })

    assert_match(/received and indexed/, output)
    assert_match(/GEMINABOX_INSECURE_SKIP_TLS_VERIFY is set/, output)
  end
end
