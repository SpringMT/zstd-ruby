require "spec_helper"
require 'zstd-ruby'

RSpec.describe Zstd::StreamingCompress do
  describe '<<' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      stream << "abc" << "def"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  describe '<< + GC.compat' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      stream << "abc" << "def"
      GC.compact
      stream << "ghi"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdefghi')
    end
  end

  describe '<< + flush' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      stream << "abc" << "def"
      res = stream.flush
      stream << "ghi"
      res << stream.finish
      expect(Zstd.decompress(res)).to eq('abcdefghi')
    end
  end

  describe 'compress + flush' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      res = stream.compress("abc")
      res << stream.flush
      res << stream.compress("def")
      res << stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  describe 'compression level' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new(5)
      stream << "abc" << "def"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    describe 'Ractor' do
      it 'should be supported' do
        r = Ractor.new {
          stream = Zstd::StreamingCompress.new(5)
          stream << "abc" << "def"
          res = stream.finish
        }
        expect(Zstd.decompress(r.take)).to eq('abcdef')
      end
    end
  end
end
