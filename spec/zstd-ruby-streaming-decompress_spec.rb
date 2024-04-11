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

  describe 'dictionary streaming decompress + GC.compact' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      compressed_json = Zstd.compress(user_json, dict: dictionary)
      stream = Zstd::StreamingDecompress.new(dict: dictionary)
      result = ''
      result << stream.decompress(compressed_json[0, 5])
      result << stream.decompress(compressed_json[5, 5])
      GC.compact
      result << stream.decompress(compressed_json[10..-1])
      expect(result).to eq(user_json)
    end
  end

  describe 'nil dictionary streaming decompress + GC.compact' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      compressed_json = Zstd.compress(user_json)
      stream = Zstd::StreamingDecompress.new(dict: nil)
      result = ''
      result << stream.decompress(compressed_json[0, 5])
      result << stream.decompress(compressed_json[5, 5])
      GC.compact
      result << stream.decompress(compressed_json[10..-1])
      expect(result).to eq(user_json)
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    describe 'Ractor' do
      it 'should be supported' do
        r = Ractor.new {
          cstr = Zstd.compress('foo bar buzz')
          stream = Zstd::StreamingDecompress.new
          result = ''
          result << stream.decompress(cstr[0, 5])
          result << stream.decompress(cstr[5, 5])
          result << stream.decompress(cstr[10..-1])
          result
        }
        expect(r.take).to eq('foo bar buzz')
      end
    end
  end
end

