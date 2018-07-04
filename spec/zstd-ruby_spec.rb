require "spec_helper"
require 'zstd-ruby'

RSpec.describe Zstd do
  it "has a version number" do
    expect(Zstd::VERSION).not_to be nil
  end

  describe 'zstd_version' do
    it 'should work' do
      expect(Zstd.zstd_version).to eq(10305)
    end
  end

  describe 'compress' do
    it 'should work' do
      compressed = Zstd.compress('abc')
      expect(compressed).to be_a(String)
      expect(compressed).to_not eq('abc')
    end

    it 'should support compression levels' do
      compressed = Zstd.compress('abc', 1)
      expect(compressed).to be_a(String)
      expect(compressed).to_not eq('abc')
    end
  end

  describe 'decompress' do
    it 'should work' do
      compressed = Zstd.compress('abc')
      decompressed = Zstd.decompress(compressed)
      expect(decompressed).to eq('abc')
    end

    it 'should work for empty strings' do
      compressed = Zstd.compress('')
      expect(compressed.bytesize).to eq(9)
      decompressed = Zstd.decompress(compressed)
      expect(decompressed).to eq('')
    end

    it 'performs streaming decompression' do
      input = 200_000.times.map { (67 + rand(10)).chr }.join
      compressed = Zstd.compress(input)
      enumerator = compressed.each_char.each_slice(4_000).lazy.map(&:join)
      expect(enumerator.to_a.join).to eq(compressed)
      decompressed = ''
      Zstd.decompress_streaming(enumerator) do |buffer|
        decompressed << buffer
      end
      expect(decompressed).to eq(input)
    end

    it 'performs streaming decompression on two concatenated frames' do
      compressed = Zstd.compress('abc')
      decompressed = ''
      enumerator = [compressed, compressed].to_enum
      Zstd.decompress_streaming(enumerator) do |buffer|
        decompressed << buffer
      end
      expect(decompressed).to eq('abcabc')
    end
  end
end

