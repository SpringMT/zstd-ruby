$LOAD_PATH.unshift '../lib'
require 'zstd-ruby'
require 'securerandom'

# 1<<17 だと GitHub ActionsでOOMになる
source_data =  Random.bytes(1<<16)

puts "source_data.size:#{source_data.size}"

# Test compressing and de-compressing our source data 100,000 times.  The cycles
# are intended to exercise the libary and reproduce a memory leak.
10.times do |i|
  compressed_data = Zstd.compress(source_data)
  expanded_data = Zstd.decompress(compressed_data)
  unless expanded_data == source_data
    puts "Error: expanded data does not match source data"
  end
  puts " - #{i}: c:#{compressed_data.size} e:#{expanded_data.size} memory:#{`ps -o rss= -p #{Process.pid}`.to_i}"
end
