[![Gem Version](https://badge.fury.io/rb/zstd-ruby.svg)](https://badge.fury.io/rb/zstd-ruby)
![Build Status](https://github.com/SpringMT/zstd-ruby/actions/workflows/ruby.yml/badge.svg?branch=master)

# zstd-ruby

Ruby binding for zstd(Zstandard - Fast real-time compression algorithm)

See https://github.com/facebook/zstd

Fork from https://github.com/jarredholman/ruby-zstd.

## Zstd version
v1.5.1 (https://github.com/facebook/zstd/tree/v1.5.1)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'zstd-ruby'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install zstd-ruby

## Usage

```ruby
require 'zstd-ruby'
```

### compression

```ruby
compressed_data = Zstd.compress(data)
compressed_data = Zstd.compress(data, complession_level) # default compression_level is 0
```


### decompression

```ruby
data = Zstd.decompress(compressed_data)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SpringMT/zstd_ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [BSD-3-Clause License](https://opensource.org/licenses/BSD-3-Clause).

