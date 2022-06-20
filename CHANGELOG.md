See https://github.com/geminabox/geminabox/releases.

- https://github.com/geminabox/geminabox/releases/tag/v1.4.3
- https://github.com/geminabox/geminabox/releases/tag/v1.4.2

# 1.4.1 (2021-05-30)

- https://github.com/geminabox/geminabox/releases/tag/v1.4.1
# 1.4.0 (2021-05-30)

- https://github.com/geminabox/geminabox/releases/tag/v1.4.0

# 1.3.1 (2021-05-30)

- https://github.com/geminabox/geminabox/releases/tag/v1.3.1

# 1.3.0 (2021-03-18)

- https://github.com/geminabox/geminabox/releases/tag/v1.3.0

# 1.2.0 (2020-03-05)

- https://github.com/geminabox/geminabox/releases/tag/v1.2.0

# 1.1.1 (2018-11-08)

- https://github.com/geminabox/geminabox/releases/tag/v1.1.1

# 1.1.0 (2018-04-06)

- https://github.com/geminabox/geminabox/releases/tag/v1.1.1

# 1.0.1 (2018-03-04)

- https://github.com/geminabox/geminabox/releases/tag/v1.0.1

# 1.0.0 (2018-02-01)

- https://github.com/geminabox/geminabox/releases/tag/v1.0.0

# 0.13.15 (2018-01-26)

Fixes:

* Fix typo: avoid NameError - uninitialized constant Geminabox::Hostess::Gemianbox (thanks to Evgeni Golov)

# 0.13.14 (2018-01-25)

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

# 0.13.13 (2018-01-11)

Fixes:

* Update link to issue shown at an error message (thanks to Tobias L. Maier)
* Hide delete button if delete disabled in gem view (thanks to Tobias L. Maier)

# 0.13.12

yanked

# 0.13.11 (2017-11-17)

Fixes:

* Fix \_cache file is not closed

# 0.13.10 (2017-11-13)

Fix vulnerabilities:

* Fix stored XSS vulnerabilities - CVE-2017-16792 (reported by Yasin Soliman)

# 0.13.9 (2017-09-25)

Enhancements:

* Make it be configurable HTTPClient options of Geminabox.http_adapter

# 0.13.8 (2017-09-24)

Fixes:

* gem inabox command should unescape username/password of geminabox url
* gem inabox command should get gemname from gemspec rather than directory name
* Concurrent reindex(:force_rebuild) should be serialized

# 0.13.7 (2017-09-23)

Fix vulnerabilities:

* Fix CSRF vulnerabilities - CVE-2017-14683 (reported by Barak Tawily)

# 0.13.6 (2017-09-19)

Fix vulnerabilities:

* Fix XSS vulnerabilities - CVE-2017-14506 (reported by Barak Tawily)

# 0.13.5 (2017-01-14)

Fixes:

* disk_cache.rb: ignore Errno::ENOENT, and EOFError. There is a possibility that the file is removed by another process after checking File.exist?.

# 0.13.4 (2016-10-25)

Fixes:

* Fix allow_remote_failure was not working in proxy/file_handler

# 0.13.3 (2016-10-13)

Enhancements:

* Add force_rebuild query parameter option to reindex route #244 (thanks to kbacha)

# 0.13.2 (2016-10-13)

Enhancements:

* Add the allow_upload config #247 (thanks to CAFxX)

Fixes:

* Atomic writes proxy latest specs #245 (thanks to dsolsona)
