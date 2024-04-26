require "spec_helper"
require 'zstd-ruby'

RSpec.describe Zstd::StreamWriter do
  describe 'write' do
    it 'shoud work' do
      io = StringIO.new
      stream = Zstd::StreamWriter.new(io)
      stream.write("abc")
      stream.write("def")
      stream.finish
      io.rewind
      expect(Zstd.decompress(io.read)).to eq('abcdef')
    end
  end
end
