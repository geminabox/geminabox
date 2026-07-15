[![](https://repository-images.githubusercontent.com/463074/c53c4131-3d92-42db-85b0-52f1e88c219a)](https://github.com/geminabox)

# Gem in a Box – Really simple rubygem hosting

[![Ruby](https://github.com/geminabox/geminabox/actions/workflows/ruby.yml/badge.svg)](https://github.com/geminabox/geminabox/actions/workflows/ruby.yml?query=branch%3Amaster)
[![Gem Version](https://badge.fury.io/rb/geminabox.svg)](http://badge.fury.io/rb/geminabox)
[![Code Climate](https://codeclimate.com/github/geminabox/geminabox/badges/gpa.svg)](https://codeclimate.com/github/geminabox/geminabox)

Geminabox lets you host your own gems, and push new gems to it just like with rubygems.org.
The bundler dependencies API is supported out of the box.
Authentication is left up to either the web server, or the Rack stack.
For basic auth, try [Rack::Auth](http://www.rubydoc.info/github/rack/rack/Rack/Auth/Basic).

![screen shot](http://pics.tomlea.co.uk/bbbba6/geminabox.png)

## System Requirements

- Ruby 3.0 or later (Ruby 3.2+ recommended)
- RubyGems 3.2.3 or later (latest version recommended)

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

## Using Geminabox alongside rubygems.org

Geminabox serves only the gems you push to it. To use it together with
rubygems.org, declare it as a scoped source in your Gemfile so that every gem
is pinned to exactly one source:

```ruby
source "https://rubygems.org"

source "https://gems.example.com" do
  gem "internal-widgets"
  gem "internal-tools"
end
```

This pinning is Bundler's protection against dependency confusion: a gem name
that exists on both servers can never silently resolve to the wrong one.

### RubyGems proxy (removed in 4.0)

Earlier versions of Geminabox could proxy rubygems.org and serve remote and
local gems from one merged namespace. The feature was deprecated in 3.1.0 and
removed in 4.0:

- It relied on the RubyGems.org Dependency API
  (`/api/v1/dependencies`), which was
  [sunset on 2023-05-24](https://blog.rubygems.org/2023/02/22/dependency-api-deprecation.html),
  so the proxy had not worked for years.
- Serving remote and local gems from one namespace invites dependency
  confusion attacks and defeats Bundler's source pinning described above.

When upgrading, remove `Geminabox.rubygems_proxy` and its related settings
(`rubygems_proxy_merge_strategy`, `allow_remote_failure`, `ruby_gems_url`,
`bundler_ruby_gems_url`) from your config.ru, and point your Gemfile at
rubygems.org directly with a scoped source block as shown above. Leftover
settings won't break your server: 4.0 warns about each one and ignores it,
and the `RUBYGEMS_PROXY` and `RUBYGEMS_PROXY_MERGE_STRATEGY` environment
variables get the same startup warning. These shims go away in 5.0.

If you need a caching or mirroring proxy for rubygems.org (air-gapped
networks, bandwidth, protection against upstream yanks), use
[gemstash](https://github.com/rubygems/gemstash), maintained by the RubyGems
organization.

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

And since version 1.2.0, Geminabox supports the standard gemcutter yank API:

    gem yank my-awesome-gem -v 1.0 --host HOST

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
gem 'rackup'
gem 'webrick' # or other server you prefer
```

From there

```
docker build -t geminabox .
```

```
docker run -d -p 9292:9292 geminabox:latest
```

Your server should now be running!


## Running the tests

Running `rake` will run the complete test suite.

The test suite uses
[minitest-reporters](https://github.com/minitest-reporters/minitest-reporters)
with the default reporter. To get more detailed test output, use `rake
MINITEST_REPORTER=SpecReporter`. With this setting, output of the Geminabox
server that is started for integration tests is sent to `stdout` as well.

## Licence

[MIT_LICENSE](./MIT-LICENSE)

## ChangeLog

[CHANGELOG.md](./CHANGELOG.md)
