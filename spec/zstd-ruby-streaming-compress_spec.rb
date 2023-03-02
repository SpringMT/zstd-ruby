require "spec_helper"
require 'zstd-ruby'

shared_examples "a streaming compressor" do
  describe '<<' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new(no_gvl: no_gvl)
      stream << "abc" << "def"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  describe '<< + GC.compat' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new(no_gvl: no_gvl)
      stream << "abc" << "def"
      GC.compact
      stream << "ghi"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdefghi')
    end
  end

  describe '<< + flush' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new(no_gvl: no_gvl)
      stream << "abc" << "def"
      res = stream.flush
      stream << "ghi"
      res << stream.finish
      expect(Zstd.decompress(res)).to eq('abcdefghi')
    end
  end

  describe 'compress + flush' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new(no_gvl: no_gvl)
      res = stream.compress("abc")
      res << stream.flush
      res << stream.compress("def")
      res << stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  describe 'compression level' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new(5, no_gvl: no_gvl)
      stream << "abc" << "def"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    describe 'Ractor' do
      it 'should be supported' do
        r = Ractor.new(no_gvl) do |no_gvl|
          stream = Zstd::StreamingCompress.new(5, no_gvl: no_gvl)
          stream << "abc" << "def"
          res = stream.finish
        end
        expect(Zstd.decompress(r.take)).to eq('abcdef')
      end
    end
  end
end

RSpec.describe Zstd::StreamingCompress do
  describe "with the global lock" do
    let(:no_gvl) { false }
    it_behaves_like "a streaming compressor"
  end

  describe "without the global lock" do
    let(:no_gvl) { true }
    it_behaves_like "a streaming compressor"
  end
end

