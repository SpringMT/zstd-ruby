require 'benchmark/ips'

$LOAD_PATH.unshift '../lib'

require 'json'
require 'objspace'
require 'zstd-ruby'

p "#{ObjectSpace.memsize_of_all/1000} #{ObjectSpace.count_objects} #{`ps -o rss= -p #{Process.pid}`.to_i}"

sample_file_name = ARGV[0]

json_string = IO.read("./samples/#{sample_file_name}")

i = 0
while true do
  stream = Zstd::StreamingCompress.new
  stream << json_string
  res = stream.flush
  res << stream.finish
  if ((i % 1000) == 0 )
    GC.start
    puts "count:#{i}\truby_memory:#{ObjectSpace.memsize_of_all/1000}\tobject_count:#{ObjectSpace.count_objects}\trss:#{`ps -o rss= -p #{Process.pid}`.to_i}"
  end
  i += 1
end
