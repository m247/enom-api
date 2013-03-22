# eNom API Client

Provides a Ruby client for the eNom Reseller API.

## Installation

Add this line to your application's Gemfile:

    gem 'enom-api'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install enom-api

## Usage

    require 'enom-api'
    client = EnomAPI::Client.new('username', 'password')
    testclient = EnomAPI::Client.new('username', 'password', 'resellertest.enom.com')

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## Copyright

Copyright (c) 2009 Geoff Garside (M247 Ltd). See LICENSE for details.
