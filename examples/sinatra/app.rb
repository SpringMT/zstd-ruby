require 'sinatra'
require 'zstd-ruby'

get '/' do
  headers["Content-Encoding"] = "zstd"
  Zstd.compress('Hello world!')
end
