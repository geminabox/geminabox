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

- Ruby 2.3 through 3.1 (Ruby 2.7, 3.0, or 3.1 is highly recommended)
- RubyGems 2.5 through 3.3 (2.5.2 or higher is highly recommended)

Use RubyGems the latest version (at least 2.5.2) for as an end-user full features like [`gem yank --host`](https://github.com/rubygems/rubygems/pull/1361).

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

## Configuration

Mode of operation of a Geminabox server is controlled through the following
boolean attributes on class `Geminabox`:

| Parameter              | Purpose                                           |
|------------------------|---------------------------------------------------|
| allow\_upload          | allow uploads of gems to the server               |
| allow\_replace         | allow local gems to be replaced with new versions |
| allow\_delete          | allow deletions of local gems                     |
| rubygems\_proxy        | whether gems from an upstream rubygems server     |
| allow\_remote\_failure | serve locally cached data when upstream is down   |


There are three possible configurations for a Geminabox: a standalone server,
where you manage all gem uploads to the server yourself, a pure caching proxy
which prohibits any uploads and a caching proxy that additionally maintains an
index of locally stored gems.


## RubyGems Proxy

Geminabox can be configured to pull gems, it does not currently have, from
rubygems.org. To enable this mode you can either:

Set RUBYGEM_PROXY to true in the environment:

    RUBYGEMS_PROXY=true rackup

Or in config.ru (before the run command), set:

    Geminabox.rubygems_proxy = true

If you want Geminabox to carry on providing gems when rubygems.org is
unavailable, add this to config.ru:

    Geminabox.allow_remote_failure = true


### Geminabox Proxy Behavior

When serving a gem, a locally stored and indexed version is always preferred
over a gem with the same name and version available on the remote server.

Gems that are automatically retrieved from rubygems are stored in a cache that
is separate from the gem store of the gems you have uploaded yourself to the
Geminabox server instance.

When serving gem index information, the list of versions for a particular gem
consists of either all the versions in the local index or all the versions in
the remote index, where the local version list for the given gem takes
precedence over the remote version list.

Which means that once a gem ends up in the local index of the Geminabox
instance, all remote versions of a gem with that name available on rubygems
become invisible in the index information served and are also not download-able
from the server anymore. Moreover, additional versions of that gem will need to
be manually uploaded to the Geminabox server instance.

This strategy is unavoidable to protect you against the following scenarios:

1) If you happen to have an in-house gem on your server which was developed some
time ago, but was never published on rubygems.org, and someday someone comes
along and picks the same gem name for his or her own project, then you really
don't want to merge the version lists of those gems. They are two completely
separate entities.

2) Even worse, some attacker might create a malicious gem which is a slightly
modified version of one of your in-house gems and put it on the rubygems
server. You really, really don't want that gem to be served by you Geminabox
instance. We know that this has happened at least once already.

Geminabox in proxy mode will ignore uploads of gem versions that are exact
copies of gems available from rubygems in order to avoid pushing you into the
manual upload mode for proxied gems.


### Upgrading from older Geminabox versions

Geminabox ships with a Ruby program to help with server upgrades. The script is
named `geminabox`. It also supports converting between standalone and proxy
servers and can be used to trigger index builds.

One complete index rebuild is necessary to activate the new bundler API on an
existing server. If you start with a new server, this will happen automatically.

```
geminabox reindex
```

This will force an index rebuild.

`geminabox proxy` will move gems that can be verified to be just proxied ones
from the local gem index to the proxy cache from gems and rebuild the index.

`geminabox standalone` will move all cached gems to the local gem store and
rebuild the indexes.

Call `geminabox --help` to get more information.


## HTTP adapter

Geminabox uses the HTTPClient gem to manage its connections to remote resources.
The relationship is managed via Geminabox::HttpClientAdapter.

To configure options of HTTPClient, pass your own HTTPClient object in config.ru
as:

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
the alternative HTTP gem. It should also be able to handle HTTP proxy settings.

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
