# Changelog

## [Unreleased]

## [4.1.1] - 2026-11-20

### Security
- **The upload metadata cap now covers `checksums.yaml.gz`**
  ([GHSA-4mrv-pqwx-3qh2](https://github.com/geminabox/geminabox/security/advisories/GHSA-4mrv-pqwx-3qh2)).
  RubyGems YAML-parses a gem's `checksums.yaml.gz` before its spec, with
  its own 10 MiB limit, and 4.1.0 capped only the spec metadata, so a gem
  with a small spec and an inflated checksums file still cost hundreds of
  megabytes of memory to reject (a 590 KiB upload took about 600 MiB).
  `checksums.yaml.gz` now gets the same `Geminabox.max_metadata_size` cap,
  checked before anything is parsed. Real gems carry a few hundred bytes of
  checksums and are unaffected. Upgrade from 4.1.0 if your server accepts
  uploads from people you do not trust.

## [4.1.0] - 2026-11-20

### Upgrade note: `gem inabox` now verifies TLS certificates
Pushes to an `https://` server whose certificate this machine does not
trust now fail, where earlier versions accepted any certificate. Servers
with a public certificate (Let's Encrypt and the like) need no change. For a
self-signed certificate or a private CA, trust the CA the way `gem install`
already does: add it to the system trust store, name it with
`:ssl_ca_cert:` in `~/.gemrc`, or set `SSL_CERT_FILE` for the push. To keep
the old behavior, set `GEMINABOX_INSECURE_SKIP_TLS_VERIFY=1`; the client
warns on every push while it is set. A failed push prints these options.
See "TLS certificates" in the README.

### Security
- **`gem inabox` verifies the server's TLS certificate**
  ([GHSA-c6m7-24q6-m3xc](https://github.com/geminabox/geminabox/security/advisories/GHSA-c6m7-24q6-m3xc)).
  The default HTTP adapter set `VERIFY_NONE` and sent Basic auth
  credentials on the first request, so anyone on the network path could
  take the push credentials and the gem, and answer with a fake success.
  Both shipped adapters now verify against the system trust store and the
  gemrc settings RubyGems uses (`ssl_ca_cert`, `ssl_client_cert`,
  `ssl_verify_mode`). The opt-out is described above. (thanks to @7a6163)
- **Uploaded gem specs are validated before they reach the index**
  ([GHSA-4mrv-pqwx-3qh2](https://github.com/geminabox/geminabox/security/advisories/GHSA-4mrv-pqwx-3qh2),
  [GHSA-882c-jvgp-8hxv](https://github.com/geminabox/geminabox/security/advisories/GHSA-882c-jvgp-8hxv)).
  One upload with a malformed version or requirement made `GET /` and the
  dependency API return 500 for every user until the file was removed from
  disk; a dependency name containing a newline, `|`, `,` or `:` injected
  lines into `/info/NAME`; and a legacy platform alias (`i686-linux`,
  `mswin32`, `jruby`) was stored under a filename the index could not
  find. Such uploads now get a 400. Gems that install today are unaffected.
  (thanks to @7a6163)
- **Gemspec metadata is capped at 1 MiB before it is parsed**
  ([GHSA-4mrv-pqwx-3qh2](https://github.com/geminabox/geminabox/security/advisories/GHSA-4mrv-pqwx-3qh2)).
  RubyGems parses spec YAML into roughly 50 times its size in memory and
  allows 10 MiB of it, so one upload could exhaust a worker. Uploads over
  the cap get a 400. Change it with `Geminabox.max_metadata_size` (bytes;
  `nil` leaves only RubyGems' limit). (thanks to @7a6163)

### Internal
- CI: test on Ruby 3.3.14, 3.4.13 and 4.0.10; `ruby/setup-ruby` v1.343.0.
- The `HttpClientAdapter` unit tests were running against
  `TemplateFaradayAdapter` (both test classes had the same name); they now
  test the right adapter, and a stub that never matched is fixed.
- The SSL integration test generates its CA and localhost certificate per
  run, replacing a fixture certificate that expired in 2022, and covers
  trusted, untrusted, gemrc and opted-out pushes.

## [4.0.1] - 2026-09-27

### Security
- **Uploaded gem names are validated before they become a path**
  ([GHSA-rxr4-84rf-f47h](https://github.com/geminabox/geminabox/security/advisories/GHSA-rxr4-84rf-f47h)).
  The destination file name was built from the name inside the uploaded
  gem's spec, which RubyGems does not validate on read, so a crafted gem
  named `../../x` could be written outside `Geminabox.data/gems` by anyone
  able to upload. Uploads whose name does not match RubyGems' own name rule
  are now rejected with a 400. (thanks to @NotAFlightRisk)
- Gem downloads and `DELETE /gems/*.gem` now return 404 for any path that
  resolves outside `Geminabox.data`, rather than relying on
  `Rack::Protection::PathTraversal` alone. That middleware is on by
  default, so default deployments were not exposed. (#770)

### Internal
- CI: pinned `actions/stale` to a commit SHA, stopped persisting the
  checkout token, and hardened the Prettier workflow (read-only token, no
  npm install scripts, runs the installed `prettier` instead of `npx`).
  (#763, #765, #766, #767)

## [4.0.0] - 2026-09-22

### Breaking Changes
- **RubyGems proxy removed.** Proxy mode (`RUBYGEMS_PROXY` env /
  `Geminabox.rubygems_proxy`), deprecated in 3.1.0, has been removed along
  with its now-unused configuration (`Geminabox.rubygems_proxy_merge_strategy`,
  `Geminabox.allow_remote_failure`, `Geminabox.ruby_gems_url`,
  `Geminabox.bundler_ruby_gems_url`) and the internal `RubygemsDependency`
  and `GemListMerge` helpers. The proxy relied on the RubyGems.org Dependency
  API (`/api/v1/dependencies`), which was
  [sunset on 2023-05-24](https://blog.rubygems.org/2023/02/22/dependency-api-deprecation.html)
  in favour of the Compact Index API, so proxy mode no longer functioned.
  It also served remote and local gems from a single merged namespace, which
  exposes users to dependency confusion attacks and defeats Bundler's
  scoped-source pinning.

  **Migration:** remove these settings from your `config.ru`; leaving them
  in place does not break startup, each logs a `[REMOVED]` warning and is
  ignored (these shims will be dropped in 5.0). Setting the
  `RUBYGEMS_PROXY` or `RUBYGEMS_PROXY_MERGE_STRATEGY` environment variables
  likewise only produces a startup warning. To use
  Geminabox alongside rubygems.org, declare it as a scoped source in your
  Gemfile (`source "https://gems.example.com" do ... end`) so each gem is
  pinned to one server; see the README. If you need a caching or mirroring
  proxy for rubygems.org, use
  [gemstash](https://github.com/rubygems/gemstash). Discussion and full
  rationale: [#735](https://github.com/geminabox/geminabox/pull/735).

### Added
- **Compact index API.** Geminabox now serves the
  [RubyGems compact index](https://guides.rubygems.org/rubygems-org-compact-index-api/)
  (`/versions`, `/info/GEMNAME`, `/names`). Bundler 1.12+ detects and uses it
  automatically with no client configuration. Responses support
  `If-None-Match` (ETag) and ranged requests, so `bundle install` only
  downloads index data that changed since the last run. The materialized
  index lives in `data/compact_index/`, is refreshed whenever gems are added
  or removed, and self-heals: deleting the directory or hitting `/reindex`
  rebuilds it from the stored gems on the next request. See the "Compact
  index" section of the README for reverse-proxy caveats and the behavior when
  a published version is replaced.
- **Web UI refresh.** Card layout, a copy-to-clipboard button on each
  install command, a permalink anchor on each gem card, and
  always-visible download/delete buttons.
  ([#747](https://github.com/geminabox/geminabox/pull/747))

### Changed
- GET responses now set an explicit content type: HTML for pages,
  `application/atom+xml` for `/atom.xml`, JSON for
  `/api/v1/dependencies.json`, and `application/octet-stream` for
  `/api/v1/dependencies`. Previously all were served as `text/html`.
  (thanks to Joseph Haig, @jrmhaig,
  [#736](https://github.com/geminabox/geminabox/pull/736))
- Deleting a version now asks for confirmation in a dialog that names the
  exact version and platform being removed, replacing the browser's
  generic `confirm()` prompt.
  ([#747](https://github.com/geminabox/geminabox/pull/747))
- `rss` is now a runtime dependency (see Fixed).
- The web UI no longer recommends `gem sources -a`, which added the server
  as a global RubyGems source. It shows a Gemfile `source` block for the
  server, and each version row offers a `gem "name", "~> X.Y.Z"` line to
  paste into it. Credentials go in `bundle config` instead of the URL.

### Fixed
- Yanking a version now removes only the requested platform build instead of
  every build of that version number.
- The Atom feed (`/atom.xml`) raised an error for any server with gems
  unless something else had loaded the `rss` gem, which provides the
  `Time#w3cdtf` it uses. `rss` left Ruby's default gems in 3.0.
  ([#736](https://github.com/geminabox/geminabox/pull/736))
- Deleting from a gem's detail page (`/gems/<name>`) submitted without any
  confirmation prompt.
  ([#747](https://github.com/geminabox/geminabox/pull/747))
- The "Back to Gem Index" link sent users to the host root when Geminabox
  is mounted under a sub-path (e.g. `Rack::URLMap` at `/gems`).
  ([#747](https://github.com/geminabox/geminabox/pull/747))
- Docker: pushes failed with a 500 when following the README, because the
  container runs as a non-root user that could not create the configured
  data directory, and a named volume mounted on it came up owned by root.
  The image now creates `/usr/src/app/data` for that user, and the README
  sets that path and mounts a volume on it so gems survive container
  replacement.

### Internal
- CI: RuboCop and the RubyGems compact-index conformance suite now run on
  every push and PR; Prettier pinned to 3.9.5.


## [3.1.0] - 2026-06-02

### Deprecated
- **RubyGems proxy** (`RUBYGEMS_PROXY` env / `Geminabox.rubygems_proxy`) is
  deprecated and **will be removed in 4.0.** It depends on the RubyGems.org
  Dependency API (`/api/v1/dependencies`), which was
  [sunset on 2023-05-24](https://blog.rubygems.org/2023/02/22/dependency-api-deprecation.html)
  in favour of the Compact Index API, so proxy mode no longer functions.
  Enabling it now emits a deprecation warning.

### Fixed
- Docker container instructions now work on modern Ruby/Rack. The example
  `Gemfile` must include `rackup` (extracted from Rack in Rack 3) and a
  server such as `webrick` (removed from Ruby's stdlib in 3.0), and the
  container now starts with `bundle exec rackup`. Without these the
  documented container failed to boot. (thanks to Ivan Kuchin, @toy)

### Internal
- CI: pinned `gem-push` workflow actions to commit SHAs and bumped
  `ruby/setup-ruby` to v1.310.0.
- CI: bumped `actions/checkout` to v6.0.3 for Node 24 compatibility.
- Relaxed the `minitest` development dependency to `< 5.27`.

## [3.0.0] - 2026-02-21

### Breaking Changes
- **Ruby >= 3.0 required.** Ruby 2.x is no longer supported.
  Users on Ruby 2.x should pin to `gem 'geminabox', '~> 2.2'`.
- **Sinatra upgraded from 2.x to 4.x.** If you mount geminabox inside a
  larger Rack/Sinatra application, review the
  [Sinatra 3.0](https://github.com/sinatra/sinatra/blob/main/CHANGELOG.md#300--2024-01-19)
  and [4.0](https://github.com/sinatra/sinatra/blob/main/CHANGELOG.md#400--2024-01-19)
  changelogs for breaking changes.
- **RubyGems >= 3.2.3 required** (up from 2.5.0).
- **`rubygems-generate_index` is now a hard dependency** and no longer needs
  to be installed separately. Remove it from your Gemfile if you added it
  for geminabox 2.2.
- **`Geminabox.build_legacy` removed.** This setting was deprecated and had
  no effect. `Gem::Indexer` itself dropped the `build_legacy` option in
  [RubyGems 2.0.0](http://ruby-doc.org/stdlib-2.0.0/libdoc/rubygems/rdoc/Gem/Indexer.html)
  (2013); modern indices are always built.
- **Removed legacy index routes** (`yaml`, `yaml.Z`, `Marshal.4.8`,
  `Marshal.4.8.Z`). These formats have not been generated since RubyGems
  2.0.0 (2013) and no client meeting the `>= 3.2.3` requirement uses them.

### Added
- Ruby 4.0 support

### Changed
- Docker base image upgraded from Ruby 3.4 to 4.0
- CI matrix simplified: Ruby 3.0-4.0 only (removed 2.x matrix and
  RubyGems version testing)
- Gem delete action uses `params` instead of `request` hash for Sinatra 4
  compatibility
- Sinatra `host_authorization` configured to permit all hosts (Sinatra 4
  requires explicit opt-in)
- Modernized Ruby syntax: removed unnecessary `begin`/`end` blocks inside
  method rescue clauses, replaced `[1..-1]` with `[1..]`

### Removed
- Ruby 2.x deprecation warnings (no longer needed since 2.x is dropped)
- `rubygems-generate_index` conditional require logic (now a gemspec
  dependency)

## [2.2.0] - 2026-02-20

### Added
- Ruby 3.3 and 3.4 support
- Docker: run container as non-root user

### Changed
- **Server operators running Ruby 3.3+** must add `rubygems-generate_index`
  to their Gemfile or run `gem install rubygems-generate_index`.
  `Gem::Indexer` was extracted from RubyGems starting with Ruby 3.3 and is
  no longer bundled. The server will refuse to start with a clear error
  if the gem is missing.
- Docker base image upgraded from Ruby 3.2 to 3.4
- Pin GitHub Actions to commit SHAs for supply chain security
- CI matrix updated: Ruby 2.3-3.4, ubuntu-22.04

### Fixed
- Rakefile gemspec loading now uses `Gem::Specification.load` instead of `eval`

### Deprecated
- Ruby 2.x support. geminabox 3.0 will require Ruby >= 3.0.
  Users on Ruby 2.x should pin to `gem 'geminabox', '~> 2.2'`.

## Previous releases

See https://github.com/geminabox/geminabox/releases.

# 1.4.2 - 1.5.0

- https://github.com/geminabox/geminabox/releases/tag/v1.5.0
- https://github.com/geminabox/geminabox/releases/tag/v1.4.3
- https://github.com/geminabox/geminabox/releases/tag/v1.4.2

# 1.0.0 - 1.4.1

###### 1.4.1 (2021-05-30)

- https://github.com/geminabox/geminabox/releases/tag/v1.4.1

###### 1.4.0 (2021-05-30)

- https://github.com/geminabox/geminabox/releases/tag/v1.4.0

###### 1.3.1 (2021-05-30)

- https://github.com/geminabox/geminabox/releases/tag/v1.3.1

###### 1.3.0 (2021-03-18)

- https://github.com/geminabox/geminabox/releases/tag/v1.3.0

###### 1.2.0 (2020-03-05)

- https://github.com/geminabox/geminabox/releases/tag/v1.2.0

###### 1.1.1 (2018-11-08)

- https://github.com/geminabox/geminabox/releases/tag/v1.1.1

###### 1.1.0 (2018-04-06)

- https://github.com/geminabox/geminabox/releases/tag/v1.1.1

###### 1.0.1 (2018-03-04)

- https://github.com/geminabox/geminabox/releases/tag/v1.0.1

###### 1.0.0 (2018-02-01)

- https://github.com/geminabox/geminabox/releases/tag/v1.0.0

# 0.13.x

###### 0.13.15 (2018-01-26)

Fixes:

* Fix typo: avoid NameError - uninitialized constant Geminabox::Hostess::Gemianbox (thanks to Evgeni Golov)

###### 0.13.14 (2018-01-25)

Fixes:

* Fix memory leak caused by Rack::Session::Pool

Changes:

* Rack::Session::Pool and Rack::Protection are not enabled as default now.

Please note that Rack::Protection is not enabled as default now.
To protect your geminabox from XSS and CSRF vulnerability,
you have to embed Rack::Protection by yourself in your `config.ru` file as:

```ruby
require "geminabox"

Geminabox.data = "/var/geminabox-data" # ... or wherever

# Use Rack::Protection to prevent XSS and CSRF vulnerability if your geminabox server is open public.
# Rack::Protection requires a session middleware, choose your favorite one such as Rack::Session::Memcache.
# This example uses Rack::Session::Pool for simplicity, but please note that:
# 1) Rack::Session::Pool is not available for multiprocess servers such as unicorn
# 2) Rack::Session::Pool causes memory leak (it does not expire stored `@pool` hash)
use Rack::Session::Pool, expire_after: 1000 # sec
use Rack::Protection

run Geminabox::Server
```

###### 0.13.13 (2018-01-11)

Fixes:

* Update link to issue shown at an error message (thanks to Tobias L. Maier)
* Hide delete button if delete disabled in gem view (thanks to Tobias L. Maier)

###### 0.13.12

yanked

###### 0.13.11 (2017-11-17)

Fixes:

* Fix \_cache file is not closed

###### 0.13.10 (2017-11-13)

Fix vulnerabilities:

* Fix stored XSS vulnerabilities - CVE-2017-16792 (reported by Yasin Soliman)

###### 0.13.9 (2017-09-25)

Enhancements:

* Make it be configurable HTTPClient options of Geminabox.http_adapter

###### 0.13.8 (2017-09-24)

Fixes:

* gem inabox command should unescape username/password of geminabox url
* gem inabox command should get gemname from gemspec rather than directory name
* Concurrent reindex(:force_rebuild) should be serialized

###### 0.13.7 (2017-09-23)

Fix vulnerabilities:

* Fix CSRF vulnerabilities - CVE-2017-14683 (reported by Barak Tawily)

###### 0.13.6 (2017-09-19)

Fix vulnerabilities:

* Fix XSS vulnerabilities - CVE-2017-14506 (reported by Barak Tawily)

###### 0.13.5 (2017-01-14)

Fixes:

* disk_cache.rb: ignore Errno::ENOENT, and EOFError. There is a possibility that the file is removed by another process after checking File.exist?.

###### 0.13.4 (2016-10-25)

Fixes:

* Fix allow_remote_failure was not working in proxy/file_handler

###### 0.13.3 (2016-10-13)

Enhancements:

* Add force_rebuild query parameter option to reindex route #244 (thanks to kbacha)

###### 0.13.2 (2016-10-13)

Enhancements:

* Add the allow_upload config #247 (thanks to CAFxX)

Fixes:

* Atomic writes proxy latest specs #245 (thanks to dsolsona)
