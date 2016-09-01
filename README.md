# River

**NOTE: River is a work in progress and should be considered _extremely_ beta.**

River is a general-purpose HTTP client with eventual hopes of full HTTP/2 support (along with support for HTTP/1.1). It is built from the ground up with three major goals:

1. be fully compliant with [RFC 7540](http://httpwg.org/specs/rfc7540.html)
2. be simple and straightforward to use, in the vein of HTTPoison
3. be awesome, in the same way that Go's http library (which has built-in, transparent support for `HTTP/2`) is awesome.

## Installation

  1. Add River to your list of dependencies in `mix.exs`:

        def deps do
          [{:river, "~> 0.0.1-beta"}]
        end

  2. Ensure River is started before your application:

        def application do
          [applications: [:river]]
        end

## Caveats

1. Currently, River only knows how to make `HTTP/2` requests to `https://` endpoints. Soon, I'll add the ability to make a request via the Upgrade header so that requests to `http://` endpoints will work as well.
2. River doesn't currently speak `HTTP/1.x`. Once I finish up basic `HTTP/2` support, `HTTP1.x` is next on the roadmap. The goal when using River in your project is that you should not need to know whether the underlying connection is using `HTTP/2` or `HTTP/1.x`.
3. River is as beta as it gets, and under active development with no promises of anything being backwards compatible 😬 (until we hit `v1.0`, of course)

## Goals

[x] Basic HTTP/2 support
[ ] HTTP/1 --> HTTP/2 upgrading
[ ] Full HTTP/2 support
[ ] Full HTTP/1.x support
