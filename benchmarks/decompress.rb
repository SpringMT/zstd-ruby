require 'benchmark/ips'

require 'json'
require 'snappy'
require 'zlib'
require 'xz'
require 'lz4-ruby'

sample_file_name = ARGV[0]

Benchmark.ips do |x|
  x.report("snappy") do
    Snappy.inflate IO.read("./results/#{sample_file_name}.snappy")
  end

  x.report("gzip") do
    gz = Zlib::GzipReader.new( File.open("./results/#{sample_file_name}.gzip") )
    gz.read
    gz.close
  end

  x.report("xz") do
    XZ.decompress IO.read("./results/#{sample_file_name}.xz")
  end

  x.report("lz4") do
    LZ4::decompress IO.read("./results/#{sample_file_name}.lz4")
  end

  x.report("zstd") do
    Zstd.decompress IO.read("./results/#{sample_file_name}.zstd")
  end

end
