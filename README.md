[![Gem Version](https://badge.fury.io/rb/zstd-ruby.svg)](https://badge.fury.io/rb/zstd-ruby)
![Build Status](https://github.com/SpringMT/zstd-ruby/actions/workflows/ruby.yml/badge.svg?branch=main)

# zstd-ruby

Ruby binding for zstd(Zstandard - Fast real-time compression algorithm)

See https://github.com/facebook/zstd

Fork from https://github.com/jarredholman/ruby-zstd.

## Zstd version
[v1.5.7](https://github.com/facebook/zstd/tree/v1.5.7)

## Versioning Policy

Starting from v2.0.0, this gem follows Semantic Versioning.

- **Major version** (X.0.0): Breaking changes to the API
- **Minor version** (X.Y.0): New features, including Zstd library version updates
- **Patch version** (X.Y.Z): Bug fixes and other backward-compatible changes

### Zstd Library Updates

Updates to the underlying Zstd library version will be released as **minor version** updates, as they may introduce new features or performance improvements while maintaining backward compatibility.

**Note**: Versions prior to v2.0.0 followed the Zstd library versioning scheme with an additional patch number (e.g., 1.5.6.2). This approach has been replaced with semantic versioning to provide clearer expectations for API stability.

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

### Compression

#### Simple Compression

```ruby
compressed_data = Zstd.compress(data)  # default: 3
compressed_data = Zstd.compress(data, level: 6)
```

### Context-based Compression

For better performance with multiple operations, use reusable contexts:

```ruby
# Unified context (recommended)
ctx = Zstd::Context.new(level: 6)
compressed = ctx.compress(data)
original = ctx.decompress(compressed)

# Specialized contexts for memory optimization
cctx = Zstd::CContext.new(level: 6)  # Compression-only
dctx = Zstd::DContext.new            # Decompression-only
```

### Dictionary Compression

Dictionaries provide better compression for similar data:

```ruby
dictionary = File.read('dictionary_file')

# Using module methods
compressed = Zstd.compress(data, level: 3, dict: dictionary)
original = Zstd.decompress(compressed, dict: dictionary)

# Using contexts for better performance
ctx = Zstd::Context.new(level: 6, dict: dictionary)
compressed = ctx.compress(data)
original = ctx.decompress(compressed)
```

#### Compression with CDict

If you use the same dictionary repeatedly, you can speed up the setup by creating CDict in advance:

```ruby
cdict = Zstd::CDict.new(File.read('dictionary_file'))
compressed_using_dict = Zstd.compress("", dict: cdict)
```

The compression_level can be specified on creating CDict.

```ruby
cdict = Zstd::CDict.new(File.read('dictionary_file'), 5)
compressed_using_dict = Zstd.compress("", dict: cdict)
```

#### Streaming Compression
```ruby
stream = Zstd::StreamingCompress.new
stream << "abc" << "def"
res = stream.flush
stream << "ghi"
res << stream.finish
```

or

```ruby
stream = Zstd::StreamingCompress.new
res = stream.compress("abc")
res << stream.flush
res << stream.compress("def")
res << stream.finish
```

#### Streaming Compression with Dictionary
```ruby
stream = Zstd::StreamingCompress.new(dict: File.read('dictionary_file'))
stream << "abc" << "def"
res = stream.flush
stream << "ghi"
res << stream.finish
```

#### Streaming Compression with level and Dictionary
```ruby
stream = Zstd::StreamingCompress.new(level: 5, dict: File.read('dictionary_file'))
stream << "abc" << "def"
res = stream.flush
stream << "ghi"
res << stream.finish
```

#### Streaming Compression with CDict of level 5
```ruby
cdict = Zstd::CDict.new(File.read('dictionary_file', 5)
stream = Zstd::StreamingCompress.new(dict: cdict)
stream << "abc" << "def"
res = stream.flush
stream << "ghi"
res << stream.finish
```

### Decompression

```ruby
data = Zstd.decompress(compressed_data)
data = Zstd.decompress(compressed_data, dict: dictionary)
```

#### Decompression with DDict

If you use the same dictionary repeatedly, you can speed up the setup by creating DDict in advance:

```ruby
ddict = Zstd::Ddict.new(File.read('dictionary_file'))
data = Zstd.compress(compressed_using_dict, ddict)
```

#### Streaming Decompression
```ruby
cstr = "" # Compressed data
stream = Zstd::StreamingDecompress.new
result = ''
result << stream.decompress(cstr[0, 10])
result << stream.decompress(cstr[10..-1])
```
## API Reference

### Context Classes

#### `Zstd::Context`
Unified context for both compression and decompression.

```ruby
ctx = Zstd::Context.new                              # Default settings
ctx = Zstd::Context.new(level: 6)                    # With compression level
ctx = Zstd::Context.new(level: 6, dict: dictionary)  # With dictionary
```

- `compress(data)` → String
- `decompress(compressed_data)` → String

#### `Zstd::CContext`
Compression-only context for memory optimization.

```ruby
cctx = Zstd::CContext.new(level: 6)                  # With compression level
cctx = Zstd::CContext.new(level: 6, dict: dictionary) # With dictionary
```

- `compress(data)` → String

#### `Zstd::DContext`
Decompression-only context for memory optimization.

```ruby
dctx = Zstd::DContext.new                            # Default settings
dctx = Zstd::DContext.new(dict: dictionary)          # With dictionary
```

- `decompress(compressed_data)` → String

### Module Methods

#### Compression
- `Zstd.compress(data)` → String (default level 3)
- `Zstd.compress(data, dict: dictionary)` → String

#### Decompression
- `Zstd.decompress(compressed_data)` → String
- `Zstd.decompress(compressed_data, dict: dictionary)` → String

#### Utilities
- `Zstd.zstd_version` → Integer

### Performance Guidelines

| Use Case | Recommended API | Benefits |
|----------|----------------|----------|
| Single operations | `Zstd.compress/decompress` | Simple, no setup |
| Multiple operations | `Zstd::Context` | 2-3x faster, convenient |
| Specialized needs | `Zstd::CContext/DContext` | Direct API access |

**Compression Levels:** 1-3 (fast, 3 is default), 9-19 (better compression)

## Benchmarks

To test performance on your system:

```bash
cd benchmarks
ruby quick_benchmark.rb             # Fast overview of all APIs (recommended)
```

## JRuby
This gem does not support JRuby.

Please consider using https://github.com/luben/zstd-jni.

Sample code is below.

```
require 'java'
require_relative './zstd-jni-1.5.2-3.jar'

str = "testtest"
compressed = com.github.luben.zstd.Zstd.compress(str.to_java_bytes)
puts com.github.luben.zstd.Zstd.decompress(compressed, str.length)
```

```
% ls
test.rb              zstd-jni-1.5.2-3.jar
% ruby -v
jruby 9.3.2.0 (2.6.8) 2021-12-01 0b8223f905 OpenJDK 64-Bit Server VM 11.0.12+0 on 11.0.12+0 +jit [darwin-x86_64]
% ruby test.rb
testtest
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SpringMT/zstd-ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [BSD-3-Clause License](https://opensource.org/licenses/BSD-3-Clause).

