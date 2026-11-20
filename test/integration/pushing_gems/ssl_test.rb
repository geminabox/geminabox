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

  test "names the ways to trust the server when its certificate fails to verify" do
    output = geminabox_push(gem_file(:example), { "SSL_CERT_FILE" => nil })

    assert_match(/SSL_CERT_FILE/, output)
    assert_match(/ssl_ca_cert/, output)
    assert_match(/GEMINABOX_INSECURE_SKIP_TLS_VERIFY/, output)
  end

  test "trusts a CA named by ssl_ca_cert in gemrc, as gem install does" do
    with_gemrc(":ssl_ca_cert: #{TestCertificate.ca_file}\n") do |gemrc|
      output = geminabox_push(gem_file(:example), { "SSL_CERT_FILE" => nil, "GEMRC" => gemrc })

      assert_match(/received and indexed/, output)
    end
  end

  test "honours ssl_verify_mode: 0 in gemrc, and warns" do
    with_gemrc(":ssl_verify_mode: 0\n") do |gemrc|
      output = geminabox_push(gem_file(:example), { "SSL_CERT_FILE" => nil, "GEMRC" => gemrc })

      assert_match(/received and indexed/, output)
      assert_match(/ssl_verify_mode: 0/, output)
    end
  end

  private

  def with_gemrc(contents)
    Tempfile.create(["gemrc", ".yml"]) do |file|
      file.write("---\n#{contents}")
      file.close
      yield file.path
    end
  end

  test "pushes to an untrusted server only when TLS verification is explicitly skipped, and warns" do
    output = geminabox_push(gem_file(:example), { "SSL_CERT_FILE" => nil, "GEMINABOX_INSECURE_SKIP_TLS_VERIFY" => "1" })

    assert_match(/received and indexed/, output)
    assert_match(/GEMINABOX_INSECURE_SKIP_TLS_VERIFY is set/, output)
  end
end
