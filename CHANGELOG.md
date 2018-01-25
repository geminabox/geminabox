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
