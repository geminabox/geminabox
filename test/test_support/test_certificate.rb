require 'openssl'
require 'tempfile'

# A throwaway CA and a localhost certificate it signs, generated per process
# so they never expire. Clients trust the CA only when pointed at ca_file.
module TestCertificate
  module_function

  # Held in a Tempfile so it is removed when the process exits.
  def ca_file
    @ca_tempfile ||= Tempfile.new(["geminabox-test-ca", ".pem"]).tap do |file|
      file.write(ca_cert.to_pem)
      file.close
    end
    @ca_tempfile.path
  end

  def ca_key
    @ca_key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def ca_cert
    @ca_cert ||= build_cert(ca_key.public_key, ca_key, nil, "geminabox test CA") do |cert, ext|
      cert.add_extension(ext.create_extension("basicConstraints", "CA:TRUE", true))
      cert.add_extension(ext.create_extension("keyUsage", "keyCertSign, cRLSign", true))
    end
  end

  def localhost_key
    @localhost_key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def localhost_cert
    @localhost_cert ||= build_cert(localhost_key.public_key, ca_key, ca_cert, "localhost") do |cert, ext|
      cert.add_extension(ext.create_extension("basicConstraints", "CA:FALSE", true))
      cert.add_extension(ext.create_extension("subjectAltName", "DNS:localhost,IP:127.0.0.1,IP:::1"))
      cert.add_extension(ext.create_extension("extendedKeyUsage", "serverAuth"))
    end
  end

  def build_cert(public_key, signing_key, issuer_cert, common_name)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = rand(1 << 64)
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{common_name}")
    cert.issuer = issuer_cert ? issuer_cert.subject : cert.subject
    cert.public_key = public_key
    cert.not_before = Time.now - 60
    cert.not_after = Time.now + (24 * 60 * 60)
    ext = OpenSSL::X509::ExtensionFactory.new(issuer_cert || cert, cert)
    yield cert, ext
    cert.sign(signing_key, OpenSSL::Digest.new("SHA256"))
    cert
  end
end
