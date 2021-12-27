require "spec_helper"
require 'zstd-ruby'

RSpec.describe Zstd do
  it "has a version number" do
    expect(Zstd::VERSION).not_to be nil
  end

  describe 'zstd_version' do
    it 'should work' do
      expect(Zstd.zstd_version).to eq(10501)
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
end

