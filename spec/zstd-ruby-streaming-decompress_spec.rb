require "spec_helper"
require 'zstd-ruby'
require 'securerandom'

RSpec.describe Zstd::StreamingDecompress do
  describe 'streaming decompress' do
    it 'shoud work' do
      # str = SecureRandom.hex(150)
      str = "foo bar buzz" * 100
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      result = ''
      result << stream.decompress(cstr[0, 5])
      result << stream.decompress(cstr[5, 5])
      result << stream.decompress(cstr[10..-1])
      expect(result).to eq(str)
    end
  end

  describe 'streaming decompress + GC.compact' do
    it 'shoud work' do
      # str = SecureRandom.hex(150)
      str = "foo bar buzz" * 100
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      result = ''
      result << stream.decompress(cstr[0, 5])
      result << stream.decompress(cstr[5, 5])
      GC.compact
      result << stream.decompress(cstr[10..-1])
      expect(result).to eq(str)
    end
  end

end

