require "spec_helper"
require 'zstd-ruby'
require 'securerandom'

RSpec.describe Zstd do
  let(:user_json) do
    File.read("#{__dir__}/user_springmt.json")
  end

  it "has a version number" do
    expect(Zstd::VERSION).not_to be nil
  end

  describe 'zstd_version' do
    it 'should work' do
      expect(Zstd.zstd_version).to eq(10507)
    end
  end

  describe 'compress' do
    it 'should work' do
      compressed = Zstd.compress(user_json)
      expect(compressed).to be_a(String)
      expect(compressed).to_not eq(user_json)
    end

    it 'should support compression keyward args levels' do
      compressed = Zstd.compress(user_json, level: 1)
      compressed_default = Zstd.compress(user_json)
      expect(compressed).to be_a(String)
      expect(compressed).to_not eq(user_json)
      expect(compressed).to_not eq(compressed_default)
      expect(compressed_default.length).to be < compressed.length
    end

    it 'should compress large bytes' do
      large_string = Random.bytes(1<<17 + 15)
      compressed = Zstd.compress(large_string)
      expect(Zstd.decompress(compressed)).to eq(large_string)
    end

    it 'should raise exception with unsupported object' do
      expect { Zstd.compress(Object.new) }.to raise_error(TypeError)
    end

    class DummyForCompress
      def to_str
        'abc'
      end
    end

    it 'should convert object implicitly' do
      compressed = Zstd.compress(DummyForCompress.new)
      expect(compressed).to be_a(String)
      decompressed = Zstd.decompress(compressed)
      expect(decompressed).to eq('abc')
    end
  end

  describe 'decompress' do
    it 'should work' do
      # bounbdary is 128 bytes
      str = SecureRandom.hex(150)
      compressed = Zstd.compress(str)
      decompressed = Zstd.decompress(compressed)
      expect(decompressed).to eq(str)
    end

    it 'should work for empty strings' do
      compressed = Zstd.compress('')
      expect(compressed.bytesize).to eq(9)
      decompressed = Zstd.decompress(compressed)
      expect(decompressed).to eq('')
    end

    it 'should work for non-ascii string' do
      compressed = Zstd.compress('あああ')
      expect(compressed.bytesize).to eq(18)
      decompressed = Zstd.decompress(compressed)
      expect(decompressed.force_encoding('UTF-8')).to eq('あああ')
    end

    it 'should work hash equal streaming compress' do
      simple_compressed = Zstd.compress('あ')
      stream = Zstd::StreamingCompress.new
      stream << "あ"
      streaming_compressed = stream.finish
      expect(Zstd.decompress(simple_compressed).force_encoding('UTF-8').hash).to eq(Zstd.decompress(streaming_compressed).force_encoding('UTF-8').hash)
    end

    it 'shoud work with large streaming compress data' do
      large_strings = Random.bytes(1<<16)
      stream = Zstd::StreamingCompress.new
      res = stream.compress(large_strings)
      res << stream.flush
      res << stream.compress(large_strings)
      res << stream.compress(large_strings)
      res << stream.finish
      expect(Zstd.decompress(res)).to eq(large_strings * 3)
    end

    it 'should raise exception with unsupported object' do
      expect { Zstd.decompress(Object.new) }.to raise_error(TypeError)
    end

    class DummyForDecompress
      def to_str
        Zstd.compress('abc')
      end
    end

    it 'should convert object implicitly' do
      expect(Zstd.decompress(DummyForDecompress.new)).to eq('abc')
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    describe 'Ractor' do
      it 'should be supported' do
        r = Ractor.new { Zstd.compress('abc') }
        expect(Zstd.decompress(r.take)).to eq('abc')
      end
    end
  end
end
