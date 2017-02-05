require 'benchmark/ips'

$LOAD_PATH.unshift '../lib'

require 'json'
require 'snappy'
require 'zlib'
require 'xz'
require 'lz4-ruby'
require 'zstd-ruby'

sample_file_name = ARGV[0]

json_data = JSON.parse(IO.read("./samples/#{sample_file_name}"), symbolize_names: true)
json_string = json_data.to_json

Benchmark.ips do |x|
  x.report("snappy") do
    File.write("./results/#{sample_file_name}.snappy", Snappy.deflate(json_string))
  end

  x.report("gzip") do
    Zlib::GzipWriter.open("./results/#{sample_file_name}.gzip") do |gz|
      gz.write json_string
    end
  end

  x.report("xz") do
    File.write("./results/#{sample_file_name}.xz", XZ.compress(json_string))
  end

  x.report("lz4") do
    File.write("./results/#{sample_file_name}.lz4", LZ4::compress(json_string))
  end

  x.report("zstd") do
    File.write("./results/#{sample_file_name}.zstd", Zstd.compress(json_string))
  end
end
