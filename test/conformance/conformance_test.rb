# frozen_string_literal: true

require_relative '../test_helper'
require 'time'

# Drives rubygems' gem_server_conformance suite against a real geminabox.
#
# The suite is an RSpec CLI (installed as the gem_server_conformance binary)
# that pushes, yanks and re-fetches gems over HTTP and asserts the exact
# compact-index/legacy-index responses a conformant server must return. It
# talks to whatever UPSTREAM points at, so here we boot geminabox in a forked
# child (reusing Geminabox::TestCase's WEBrick rig) and run the CLI against it.
#
# Two endpoints the suite needs do not exist in the shipped app, so the test
# rig wraps them AROUND Geminabox::Server (see .app below) exactly like
# rubygems' own reference rig does for gemstash. Nothing test-only reaches the
# Sinatra app itself.
module ConformanceClock
  # The suite POSTs an ISO8601 instant to /set_time and then expects that
  # instant back in the compact index `created_at:` header. Geminabox stamps
  # that header from Time.now.utc when it rebuilds the versions list, so we
  # pin Time.now inside the server process. now_override is nil everywhere
  # except the forked child once /set_time has fired, so the real clock is
  # untouched in the parent test process.
  class << self
    attr_accessor :now_override
  end

  def now
    ConformanceClock.now_override || super
  end
end
Time.singleton_class.prepend(ConformanceClock)

class ConformanceTest < Geminabox::TestCase
  API_KEY = "conformance-test-key"

  app do
    set_time = lambda do |env|
      body = env["rack.input"].read
      ConformanceClock.now_override = Time.iso8601(body).utc
      [200, { "content-type" => "text/plain" }, ["OK"]]
    end

    # Compact the append-only versions.list back down to one line per gem with
    # a fresh created_at header, which is what /rebuild_versions_list means.
    # Dropping versions.list first forces reindex down its full_build path.
    rebuild_versions_list = lambda do |_env|
      indexer = Geminabox::Server.compact_indexer
      Geminabox::Server.with_rlock do
        File.delete(indexer.versions_path) if File.exist?(indexer.versions_path)
        Geminabox::Server.reindex(:force_rebuild)
      end
      [200, { "content-type" => "text/plain" }, ["OK"]]
    end

    map("/set_time") { run set_time }
    map("/rebuild_versions_list") { run rebuild_versions_list }
    run Geminabox::Server
  end

  test "geminabox is a conformant gem server" do
    skip "gem_server_conformance is not installed" unless conformance_available?

    output = run_conformance
    # Echo the suite's own summary so it lands in the CI log, pass or fail.
    puts output

    assert $?.success?, "gem_server_conformance reported failures:\n\n#{output}"
  end

  protected

  def conformance_available?
    Gem::Specification.find_by_name("gem_server_conformance")
    true
  rescue Gem::MissingSpecError
    false
  end

  def run_conformance(excluded_tags: [])
    upstream = url_for("/").chomp("/")
    exclusions = File.expand_path("rspec_exclusions.rb", __dir__)
    tag_args = excluded_tags.map { |tag| "--tag=~#{tag}" }
    command = ["bundle", "exec", "gem_server_conformance",
               "--require", exclusions, "--format", "progress", *tag_args]
    env = { "UPSTREAM" => upstream, "GEM_HOST_API_KEY" => API_KEY }

    IO.popen(env, command, err: [:child, :out], &:read)
  end
end
