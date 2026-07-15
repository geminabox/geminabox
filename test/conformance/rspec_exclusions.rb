# frozen_string_literal: true

# Loaded into the gem_server_conformance RSpec process via --require (see
# conformance_test.rb). It excludes examples the shipped geminabox cannot pass
# for reasons outside the compact-index surface this suite exists to guard.
RSpec.configure do |config|
  # /latest_specs.4.8.gz drops all but one platform of a version. Geminabox
  # delegates legacy index generation to Gem::Indexer (rubygems-generate_index),
  # whose Gem::Specification._latest_specs keys the "latest" map by gem name
  # alone, so a multi-platform release collapses to its last platform. That is
  # an upstream rubygems bug, not geminabox code, and Bundler resolves off the
  # compact index rather than this legacy file. Tracked in geminabox-bhc.
  config.filter_run_excluding(full_description: /get_specs\(:latest\)/)
end
