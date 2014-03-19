# Gem in a Box – Really simple rubygem hosting
[![Build Status](https://secure.travis-ci.org/geminabox/geminabox.png)](http://travis-ci.org/geminabox/geminabox)
[![Gem Version](https://badge.fury.io/rb/geminabox.png)](http://badge.fury.io/rb/geminabox)

Geminabox lets you host your own gems, and push new gems to it just like with rubygems.org.
The bundler dependencies API is supported out of the box.
Authentication is left up to either the web server, or the Rack stack.
For basic auth, try [Rack::Auth](http://rack.rubyforge.org/doc/Rack/Auth/Basic.html).

![screen shot](http://pics.tomlea.co.uk/bbbba6/geminabox.png)

## System Requirements

    Tested on Mac OS X 10.8.2
    Ruby 1.9.3-392

    Tests fail on Ruby 2.0.0-p0

## Server Setup

    gem install geminabox

Create a config.ru as follows:

    require "rubygems"
    require "geminabox"

    Geminabox.data = "/var/geminabox-data" # ... or wherever
    run Geminabox::Server

Start your gem server with 'rackup' to run WEBrick or hook up the config.ru as you normally would ([passenger][passenger], [thin][thin], [unicorn][unicorn], whatever floats your boat).

## Legacy RubyGems index

RubyGems supports generating indexes for the so called legacy versions (< 1.2), and since it is very rare to use such versions nowadays, it can be disabled, thus improving indexing times for large repositories. If it's safe for your application, you can disable support for these legacy versions by adding the following configuration to your config.ru file:

    Geminabox.build_legacy = false

## RubyGems Proxy

Geminabox can be configured to pull gems, it does not currently have, from rubygems.org. To enable this mode you can either:

Set RUBYGEM_PROXY to true in the environment:

    RUBYGEMS_PROXY=true rackup

Or in config.ru (before the run command), set:

    Geminabox.rubygems_proxy = true

## HTTP adapter

Geminabox uses the HTTPClient gem to manage its connections to remote resources.
The relationship is managed via Geminabox::HttpClientAdapter.

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

## Licence

Fork it, mod it, choose it, use it, make it better. All under the MIT License.

[WTFBPPL]: http://tomlea.co.uk/WTFBPPL.txt
[sinatra]: http://www.sinatrarb.com/
[passenger]: http://www.modrails.com/
[thin]: http://code.macournoyer.com/thin/
[unicorn]: http://unicorn.bogomips.org/
