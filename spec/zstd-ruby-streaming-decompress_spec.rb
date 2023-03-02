require "spec_helper"
require 'zstd-ruby'
require 'securerandom'

shared_examples "a streaming decompressor" do
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
      stream = Zstd::StreamingDecompress.new(no_gvl: no_gvl)
      result = ''
      result << stream.decompress(cstr[0, 5])
      result << stream.decompress(cstr[5, 5])
      GC.compact
      result << stream.decompress(cstr[10..-1])
      expect(result).to eq(str)
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    describe 'Ractor' do
      it 'should be supported' do
        r = Ractor.new(no_gvl) do |no_gvl|
          cstr = Zstd.compress('foo bar buzz')
          stream = Zstd::StreamingDecompress.new(no_gvl: no_gvl)
          result = ''
          result << stream.decompress(cstr[0, 5])
          result << stream.decompress(cstr[5, 5])
          result << stream.decompress(cstr[10..-1])
          result
        end
        expect(r.take).to eq('foo bar buzz')
      end
    end
  end
end

RSpec.describe Zstd::StreamingDecompress do
  describe "with the gvl" do
    let(:no_gvl) { false }
    it_behaves_like "a streaming decompressor"
  end

  describe "without the gvl" do
    let(:no_gvl) { true }
    it_behaves_like "a streaming decompressor"
  end
end

