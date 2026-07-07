require_relative '../test_helper'
require 'rack/test'

class CompactIndexTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Geminabox::Server
  end

  def setup
    clean_data_dir
    # Server.dependency_cache is memoized at the class level for the life
    # of the process, but clean_data_dir rm_rf's the whole data dir
    # (including the cache's root_path) out from under it on every test.
    # #flush recreates root_path, keeping the shared cache in sync with
    # the freshly wiped data dir.
    Geminabox::Server.dependency_cache.flush
    inject_gems do |builder|
      builder.gem "a", deps: { b: ">= 1.0" }
    end
  end

  test "GET /versions bootstraps the compact index and serves it" do
    get "/versions"
    assert last_response.ok?
    assert_equal "text/plain;charset=utf-8",
                 last_response.headers["Content-Type"].delete(" ")
    body = last_response.body
    assert_match(/\Acreated_at: /, body)
    assert_match(/^a 1\.0\.0 [0-9a-f]{32}$/, body)
    assert_equal %("#{Digest::MD5.hexdigest(body)}"), last_response.headers["ETag"]
    sha = [Digest::SHA256.digest(body)].pack("m0")
    assert_equal "sha-256=:#{sha}:", last_response.headers["Repr-Digest"]
    assert_equal "sha-256=#{sha}", last_response.headers["Digest"]
    assert_equal "bytes", last_response.headers["Accept-Ranges"]
  end

  test "GET /versions returns 304 on matching If-None-Match" do
    get "/versions"
    etag = last_response.headers["ETag"]
    get "/versions", {}, { "HTTP_IF_NONE_MATCH" => etag }
    assert_equal 304, last_response.status
    assert_equal "", last_response.body
    assert_equal etag, last_response.headers["ETag"]
  end

  test "GET /versions serves a tail for a satisfiable range" do
    get "/versions"
    full = last_response.body
    start = full.bytesize - 10
    get "/versions", {}, { "HTTP_RANGE" => "bytes=#{start}-" }
    assert_equal 206, last_response.status
    assert_equal full.byteslice(start..), last_response.body
    assert_equal "bytes #{start}-#{full.bytesize - 1}/#{full.bytesize}",
                 last_response.headers["Content-Range"]
    sha = [Digest::SHA256.digest(full)].pack("m0")
    assert_equal "sha-256=:#{sha}:", last_response.headers["Repr-Digest"],
                 "digests must describe the FULL file, even on 206"
  end

  test "GET /versions ignores an unsatisfiable range" do
    get "/versions"
    size = last_response.body.bytesize
    get "/versions", {}, { "HTTP_RANGE" => "bytes=#{size + 100}-" }
    assert_equal 200, last_response.status
    assert_equal size, last_response.body.bytesize
  end

  test "GET /info/GEMNAME serves the info file" do
    get "/versions"
    get "/info/a"
    assert last_response.ok?
    assert_match(/\A---\n1\.0\.0 b:>= 1\.0\|checksum:[0-9a-f]{64}\n\z/, last_response.body)
    assert_equal %("#{Digest::MD5.hexdigest(last_response.body)}"),
                 last_response.headers["ETag"]
  end

  test "GET /info/GEMNAME returns 404 for unknown gems" do
    get "/versions"
    get "/info/nope"
    assert_equal 404, last_response.status
  end

  test "GET /info with a null byte returns 404 rather than 500" do
    get "/versions"
    get "/info/%00"
    assert_equal 404, last_response.status
  end

  test "GET /info rejects directory traversal" do
    get "/versions"
    get "/info/.."
    # Rack::Protection::PathTraversal (Sinatra's `set :protection, true`
    # default, applied globally, pre-existing) canonicalizes ".." segments
    # out of PATH_INFO before Sinatra ever routes the request, so
    # "/info/.." arrives at our app as "/" and dispatches to the index
    # route (200) -- our /info/:name handler is never invoked for this
    # request. Confirm no compact-index file content leaks either way.
    assert_equal 200, last_response.status
    refute_match(/checksum:/, last_response.body)
  end

  test "GET /names serves the names file" do
    get "/versions"
    get "/names"
    assert last_response.ok?
    assert_equal "---\na\nb\n", last_response.body
  end

  test "GET /names bootstraps when the compact index is missing" do
    get "/names"
    assert last_response.ok?
    assert_equal "---\na\nb\n", last_response.body
  end

  test "GET /names self-heals a names file deleted under an intact versions.list" do
    get "/versions"
    names_path = Geminabox::Server.compact_indexer.names_path
    File.delete(names_path)
    refute File.exist?(names_path)

    get "/names"
    assert last_response.ok?
    assert_equal "---\na\nb\n", last_response.body
  end
end
