require "zstd-ruby/version"

begin
  # Precompiled gems ship one binary per Ruby ABI, under lib/zstd-ruby/<X.Y>/.
  # Source installs put a single binary directly in lib/zstd-ruby/.
  RUBY_VERSION =~ /\A(\d+\.\d+)/
  require "zstd-ruby/#{$1}/zstdruby"
rescue LoadError
  require "zstd-ruby/zstdruby"
end

require "zstd-ruby/stream_writer"
require "zstd-ruby/stream_reader"

module Zstd
end
