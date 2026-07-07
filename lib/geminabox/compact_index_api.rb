# frozen_string_literal: true

require 'digest'

module Geminabox

  # Sinatra helpers implementing the compact index HTTP semantics:
  # - ETag is the quoted MD5 of the full body (Bundler <= 2.4 verifies
  #   exactly that after reassembling ranged fetches).
  # - Only the open-ended range form Bundler sends (bytes=N-) is honored;
  #   anything else gets a full 200, which clients must tolerate.
  # - Repr-Digest/Digest carry sha-256 of the FULL file even on 206 —
  #   without them Bundler >= 2.5 refuses to append partial responses.
  #
  # Requires the including class to provide #dependency_cache.
  module CompactIndexApi
    def serve_compact_file(path)
      halt 404 unless File.file?(path)
      stat = File.stat(path)
      contents = File.binread(path)
      md5, sha256 = compact_file_digests(path, stat, contents)
      etag = %("#{md5}")
      headers "ETag" => etag,
              "Accept-Ranges" => "bytes",
              "Repr-Digest" => "sha-256=:#{sha256}:",
              "Digest" => "sha-256=#{sha256}",
              "Cache-Control" => "max-age=60"
      content_type "text/plain; charset=utf-8"
      halt 304 if request.env["HTTP_IF_NONE_MATCH"] == etag
      first_byte = range_start(request.env["HTTP_RANGE"], contents.bytesize)
      if first_byte
        status 206
        headers "Content-Range" =>
          "bytes #{first_byte}-#{contents.bytesize - 1}/#{contents.bytesize}"
        contents.byteslice(first_byte..)
      else
        contents
      end
    end

  private

    def range_start(header, size)
      match = /\Abytes=(\d+)-\z/.match(header.to_s)
      return unless match
      first_byte = Integer(match[1])
      first_byte < size ? first_byte : nil
    end

    def compact_file_digests(path, stat, contents)
      key = "compact_digests:#{path}:#{stat.mtime.to_f}:#{stat.size}"
      dependency_cache.marshal_cache(key) do
        [Digest::MD5.hexdigest(contents),
         [Digest::SHA256.digest(contents)].pack("m0")]
      end
    end
  end

end
