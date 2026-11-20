# frozen_string_literal: true

require 'uri'
require 'cgi/escape'
require 'geminabox'

class GeminaboxClient
  attr_reader :url, :http_client

  def initialize(url)
    extract_username_and_password_from_url!(url)
    @http_client = Geminabox.http_adapter
    @http_client.set_auth(url_for(:upload), @username, @password) 
  end

  def extract_username_and_password_from_url!(url)
    uri = URI.parse(url.to_s)
    @username = CGI.unescape(uri.user) if uri.user
    @password = CGI.unescape(uri.password) if uri.password
    uri.user = uri.password = nil
    uri.path = uri.path + "/" unless uri.path.end_with?("/")
    @url = uri.to_s
  end

  def url_for(path)
    url + path.to_s
  end

  def push(gemfile, options = {})
    response = post_gem(gemfile, options)

    if response.status < 300
      response.body
    else
      raise GeminaboxClient::Error, "Error (#{response.status} received)\n\n#{response.body}"
    end
  end

  private

  def post_gem(gemfile, options)
    http_client.post(url_for(:upload), { 'file' => File.open(gemfile, "rb"), 'overwrite' => !!options[:overwrite] }, { 'Accept' => 'text/plain' })
  rescue StandardError => e
    raise unless certificate_failure?(e)

    raise GeminaboxClient::Error, untrusted_certificate_message(e)
  end

  # Faraday wraps OpenSSL's error, so match on the message rather than the class.
  def certificate_failure?(error)
    error.message.include?("certificate verify failed")
  end

  def untrusted_certificate_message(error)
    <<~MESSAGE
      Could not verify the TLS certificate of #{url}
        #{error.message}

      If the server uses a self-signed certificate or a private CA, trust that CA by either:
        - SSL_CERT_FILE=/path/to/ca.pem gem inabox ...
        - adding ":ssl_ca_cert: /path/to/ca.pem" to ~/.gemrc (gem install reads it too)
        - adding the CA to the system trust store

      To push without verifying (anyone on the network path can then read your
      credentials and the gem), set GEMINABOX_INSECURE_SKIP_TLS_VERIFY=1.
    MESSAGE
  end

end

class GeminaboxClient::Error < RuntimeError
end

module GeminaboxClient::GemLocator
  def find_gem(dir)
    gemspec_path = Dir.glob(File.join(dir, "*.gemspec")).first
    gemspec = Gem::Specification::load(gemspec_path)
    gemname = gemspec.name
    glob_matcher = "{pkg/,}#{gemname}-*.gem"
    latest_gem_for(gemname, Dir.glob(glob_matcher)) or raise Gem::CommandLineError, NO_GEM_PROVIDED_ERROR_MESSAGE
  end

  def latest_gem_for(gemname, files)
    regexp_matcher = %r{(?:pkg/)#{gemname}-(#{Gem::Version::VERSION_PATTERN})\.gem}
    sorter = lambda{|v| Gem::Version.new(regexp_matcher.match(v)[1]) }
    files.grep(regexp_matcher).max_by(&sorter)
  end

  extend self

  NO_GEM_PROVIDED_ERROR_MESSAGE = "Couldn't find a gem in pkg, please specify a gem name on the command line (e.g. gem inabox GEMNAME)"
end
