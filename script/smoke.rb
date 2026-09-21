# Exercises the installed zstd-ruby gem. Used by the precompile workflow to
# check that each platform gem loads and works on a real target system.
# Run it from outside the repo's load path, so the installed gem is used:
#
#   gem install --no-document ./pkg/zstd-ruby-*.gem
#   ruby script/smoke.rb

require "stringio"
require "zstd-ruby"

def check(what)
  raise "smoke: #{what} failed" unless yield
end

data = "the quick brown fox jumps over the lazy dog\n" * 5000

# simple
check("round trip") { Zstd.decompress(Zstd.compress(data)) == data }
check("compression happened") { Zstd.compress(data).bytesize < data.bytesize }
check("level") { Zstd.decompress(Zstd.compress(data, level: 19)) == data }

# concatenated frames
two = Zstd.compress("abc") + Zstd.compress("def")
check("concatenated frames") { Zstd.decompress(two) == "abcdef" }

# streaming compression
stream = Zstd::StreamingCompress.new
stream << "abc" << "def"
res = stream.flush
stream << "ghi"
res << stream.finish
check("streaming round trip") { Zstd.decompress(res) == "abcdefghi" }

# streaming decompression, split mid-frame
compressed = Zstd.compress(data)
stream = Zstd::StreamingDecompress.new
result = +""
result << stream.decompress(compressed[0, 10])
result << stream.decompress(compressed[10..-1])
check("streaming decompress") { result == data }

# dictionary, including the CDict/DDict path
samples = Array.new(20) { |i| "key#{i}: the quick brown fox\n" * 10 }
dict = samples.join
cdict = Zstd::CDict.new(dict)
ddict = Zstd::DDict.new(dict)
with_dict = Zstd.compress(samples.first, dict: cdict)
check("dictionary round trip") { Zstd.decompress(with_dict, dict: ddict) == samples.first }

# skippable frame
framed = Zstd.write_skippable_frame(Zstd.compress("abc"), "sample data")
check("skippable frame") { Zstd.read_skippable_frame(framed) == "sample data" }

# StreamWriter / StreamReader wrappers
io = StringIO.new
writer = Zstd::StreamWriter.new(io)
writer.write(data)
writer.finish
io.rewind
reader = Zstd::StreamReader.new(io)
read_back = +""
read_back << reader.read(8192) until io.eof?
check("StreamWriter/StreamReader") { read_back == data }

# Multi-threaded compression is enabled at build time (-DZSTD_MULTITHREAD);
# make sure it survives cross-compilation.
threads = 4.times.map { Thread.new { Zstd.decompress(Zstd.compress(data)) } }
check("threaded round trip") { threads.map(&:value).all? { |v| v == data } }

binary = $LOADED_FEATURES.grep(/zstdruby\.(so|bundle|dll)\z/).first
puts "ok: zstd-ruby #{Zstd::VERSION} on ruby #{RUBY_VERSION} #{RUBY_PLATFORM}"
puts "    binary: #{binary}"
