require 'benchmark/ips'

$LOAD_PATH.unshift '../lib'

require 'json'
require 'zstd-ruby'
require 'objspace'

p "#{ObjectSpace.memsize_of_all/1000} #{ObjectSpace.count_objects} #{`ps -o rss= -p #{Process.pid}`.to_i}"

sample_file_name = ARGV[0]
json_data = JSON.parse(File.read("./samples/#{sample_file_name}"), symbolize_names: true)
json_string = json_data.to_json

i = 0
start_time = Time.now
while true do
  Zstd.decompress IO.read("./results/#{sample_file_name}.zstd")
  if ((i % 1000) == 0 )
     puts "sec:#{Time.now - start_time}\tcount:#{i}\truby_memory:#{ObjectSpace.memsize_of_all/1000}\tobject_count:#{ObjectSpace.count_objects}\trss:#{`ps -o rss= -p #{Process.pid}`.to_i}"
  end
  i += 1
end
