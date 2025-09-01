require 'benchmark/ips'

$LOAD_PATH.unshift '../lib'
require 'zstd-ruby'

# Sample data - size typical of real-world scenarios
data = "Hello, World! " * 1000  # ~13KB string

# Pre-compress data for decompression tests
compressed_data = Zstd.compress(data)

puts "Benchmarking context reuse vs module methods"
puts "Data size: #{data.bytesize} bytes, Compressed: #{compressed_data.bytesize} bytes"
puts

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)
  
  # Compression benchmarks
  x.report("Module compress (new context each time)") do
    Zstd.compress(data)
  end
  
  ctx = Zstd::Context.new
  x.report("Context compress (reused)") do
    ctx.compress(data)
  end
  
  cctx = Zstd::CContext.new
  x.report("CContext compress (reused)") do
    cctx.compress(data)
  end
  
  # Decompression benchmarks
  x.report("Module decompress (new context each time)") do
    Zstd.decompress(compressed_data)
  end
  
  x.report("Context decompress (reused)") do
    ctx.decompress(compressed_data)
  end
  
  dctx = Zstd::DContext.new
  x.report("DContext decompress (reused)") do
    dctx.decompress(compressed_data)
  end
  
  x.compare!
end