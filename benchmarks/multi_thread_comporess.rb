require 'benchmark/ips'
$LOAD_PATH.unshift '../lib'
require 'json'
require 'objspace'
require 'zstd-ruby'
require 'thread'

GUESSES = (ENV['GUESSES'] || 1000).to_i
THREADS = (ENV['THREADS'] || 1).to_i

p GUESSES: GUESSES, THREADS: THREADS

sample_file_name = ARGV[0]
json_string = File.read("./samples/#{sample_file_name}")

queue = Queue.new
GUESSES.times { queue << json_string }
THREADS.times { queue << nil }
THREADS.times.map {
  Thread.new {
    while str = queue.pop
      Zstd.compress(str)
    end
  }
}.each(&:join)
