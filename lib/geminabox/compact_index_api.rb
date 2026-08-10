# frozen_string_literal: true

require 'digest'

module Geminabox
  # Sinatra helpers implementing the compact index HTTP semantics:
  # - ETag is the quoted MD5 of the full body (Bundler <= 2.4 verifies
  #   exactly that after reassembling ranged fetches).
  # - A single byte range is honored in all three forms (bytes=N-, bytes=N-M,
  #   bytes=-N); Bundler only ever sends the open-ended tail. Multipart,
  #   malformed, and unsatisfiable ranges get a full 200 rather than a 416,
  #   which clients must tolerate (RFC 9110 permits ignoring Range).
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
      range = byte_range(request.env["HTTP_RANGE"], contents.bytesize)
      if range
        status 206
        headers "Content-Range" =>
          "bytes #{range.begin}-#{range.end}/#{contents.bytesize}"
        contents.byteslice(range)
      else
        contents
      end
    end

    private

    # Inclusive byte range to serve, or nil to serve the whole body.
    def byte_range(header, size)
      match = /\Abytes=(\d*)-(\d*)\z/.match(header.to_s)
      return if match.nil? || size.zero?

      first, last = match.captures
      return suffix_range(last, size) if first.empty?

      first_byte = Integer(first)
      return if first_byte >= size

      last_byte = last.empty? ? size - 1 : [Integer(last), size - 1].min
      first_byte..last_byte unless last_byte < first_byte
    end

    # bytes=-N asks for the final N bytes; N == 0 is unsatisfiable.
    def suffix_range(last, size)
      return if last.empty?

      length = Integer(last)
      return if length.zero?

      [size - length, 0].max..(size - 1)
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
