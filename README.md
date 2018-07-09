# Gem in a Box – Really simple rubygem hosting
[![Build Status](https://secure.travis-ci.org/geminabox/geminabox.png)](http://travis-ci.org/geminabox/geminabox)
[![Gem Version](https://badge.fury.io/rb/geminabox.png)](http://badge.fury.io/rb/geminabox)
[![Code Climate](https://codeclimate.com/github/geminabox/geminabox/badges/gpa.svg)](https://codeclimate.com/github/geminabox/geminabox)

Geminabox lets you host your own gems, and push new gems to it just like with rubygems.org.
The bundler dependencies API is supported out of the box.
Authentication is left up to either the web server, or the Rack stack.
For basic auth, try [Rack::Auth](http://www.rubydoc.info/github/rack/rack/Rack/Auth/Basic).

![screen shot](http://pics.tomlea.co.uk/bbbba6/geminabox.png)

## System Requirements

See [.travis.yml](./.travis.yml) for supported ruby versions

## Server Setup

    gem install geminabox

Create a config.ru as follows:

    require "rubygems"
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

Start your gem server with 'rackup' to run WEBrick or hook up the config.ru as you normally would ([passenger](https://www.phusionpassenger.com/), [thin](http://code.macournoyer.com/thin/), [unicorn](https://bogomips.org/unicorn/), whatever floats your boat).

## Legacy RubyGems index

RubyGems supports generating indexes for the so called legacy versions (< 1.2), and since it is very rare to use such versions nowadays, it can be disabled, thus improving indexing times for large repositories. If it's safe for your application, you can disable support for these legacy versions by adding the following configuration to your config.ru file:

    Geminabox.build_legacy = false

## RubyGems Proxy

Geminabox can be configured to pull gems, it does not currently have, from rubygems.org. To enable this mode you can either:

Set RUBYGEM_PROXY to true in the environment:

    RUBYGEMS_PROXY=true rackup

Or in config.ru (before the run command), set:

    Geminabox.rubygems_proxy = true

If you want Geminabox to carry on providing gems when rubygems.org is unavailable, add this to config.ru:

    Geminabox.allow_remote_failure = true

### Index File Caching

If Geminabox is configured to act as a proxy it will download the latest index file and merge it with the local
index on every request. This may create some serious performance issues if multiple clients are using the service.

To work around this it is possible to activate index file caching. To use it you will need a cache store that is
compatible with 'cachy' like for example 'moneta' or 'memcached'.

To configure a simple moneta file cache store add the following to the config.ru:

```ruby
Geminabox.cache_store = Moneta.new(:File, dir: File.join('/path/to/data/dir/_index_cache'), expires: 1800)
```

## HTTP adapter

Geminabox uses the HTTPClient gem to manage its connections to remote resources.
The relationship is managed via Geminabox::HttpClientAdapter.

To configure options of HTTPClient, pass your own HTTPClient object in config.ru as:

```ruby
# Geminabox.http_adapter = Geminabox::HttpClientAdapter.new # default
Geminabox.http_adapter.http_client = HTTPClient.new(ENV['http_proxy']).tap do |http_client|
  http_client.transparent_gzip_decompression = true
  http_client.keep_alive_timeout = 32 # sec
  http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http_client.send_timeout = 0
  http_client.receive_timeout = 0
end
```

If you would like to use an alternative HTTP gem, create your own adapter
and specify it in config.ru:

    Geminabox.http_adapter = YourHttpAdapter.new

It is recommend (but not essential) that your adapter inherits from HttpAdapter.
The adapter will need to replace HttpAdapter's methods with those specific to
the alternative HTTP gem. It should also be able to handle HTTP proxy
settings.

Defining your own adapter also allows you to configure Geminabox to use the
local systems SSL certificates.

TemplateFaradayAdapter is provided as an example of an alternative HTTPAdapter.

## Hooks

You can add a hook (anything callable) which will be called when a gem is
successfully received.

```ruby
Geminabox.on_gem_received = Proc.new do |gem|
  puts "Gem received: #{gem.spec.name} #{gem.spec.version}"
end
```

Typically you might use this to push a notification to your team chat. Any
exceptions which occur within the hook is silently ignored, so please ensure they
are handled properly if this is not desirable.

Also, please note that this hook blocks `POST /upload` and `POST /api/v1/gems` APIs processing.
Hook authors are responsible to perform any action non-blocking/async to avoid HTTP timeout.

## Client Usage

Since version 0.10, Geminabox supports the standard gemcutter push API:

    gem push pkg/my-awesome-gem-1.0.gem --host HOST

You can also use the gem plugin:

    gem install geminabox

    gem inabox pkg/my-awesome-gem-1.0.gem

Configure Gem in a box (interactive prompt to specify where to upload to):

    gem inabox -c

Change the host to upload to:

    gem inabox -g HOST

Simples!

## Command Line Help

    Usage: gem inabox GEM [options]

      Options:
        -c, --configure                  Configure GemInABox
        -g, --host HOST                  Host to upload to.
        -o, --overwrite                  Overwrite Gem.


      Common Options:
        -h, --help                       Get help on this command
        -V, --[no-]verbose               Set the verbose level of output
        -q, --quiet                      Silence commands
            --config-file FILE           Use this config file instead of default
            --backtrace                  Show stack backtrace on errors
            --debug                      Turn on Ruby debugging


      Arguments:
        GEM       built gem to push up

      Summary:
        Push a gem up to your GemInABox

      Description:
        Push a gem up to your GemInABox

## Docker

Using Gem in a Box is really simple with the Dockerfile.  Move this Dockerfile into a directory that you want to use for your server.

That directory only needs to contain:

```
config.ru (explained above)
Gemfile
Gemfile.lock
```

Your Gemfile only needs:

```ruby
source 'https://rubygems.org'

gem 'geminabox'
```

From there

```
docker build -t geminabox .
```

```
docker run -d -p 9292:9292 geminabox:latest
```

Your server should now be running!

## Licence

[MIT_LICENSE](./MIT-LICENSE)

## ChangeLog

[CHANGELOG.md](./CHANGELOG.md)
