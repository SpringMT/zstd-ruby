require 'benchmark/ips'

$LOAD_PATH.unshift '../lib'

require 'json'
require 'zstd-ruby'
require 'objspace'

p "#{ObjectSpace.memsize_of_all/1000} #{ObjectSpace.count_objects} #{`ps -o rss= -p #{Process.pid}`.to_i}"

sample_file_name = ARGV[0]

cstr = IO.read("./results/#{sample_file_name}.zstd")
i = 0
while true do
  stream = Zstd::StreamingDecompress.new
  result = ''
  result << stream.decompress(cstr[0, 10])
  result << stream.decompress(cstr[10..-1])

  if ((i % 1000) == 0 )
    GC.start
    puts "count:#{i}\truby_memory:#{ObjectSpace.memsize_of_all/1000}\tobject_count:#{ObjectSpace.count_objects}\trss:#{`ps -o rss= -p #{Process.pid}`.to_i}"
  end
  i += 1
end
