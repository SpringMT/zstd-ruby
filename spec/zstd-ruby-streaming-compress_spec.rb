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
      stream = Zstd::StreamingCompress.new(level: 5)
      stream << "abc" << "def"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  describe 'String dictionary' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      dict_stream = Zstd::StreamingCompress.new(level: 5, dict: dictionary)
      dict_stream << user_json
      dict_res = dict_stream.finish
      stream = Zstd::StreamingCompress.new(level: 5)
      stream << user_json
      res = stream.finish

      expect(dict_res.length).to be < res.length
    end
  end

  describe 'Zstd::CDict dictionary' do
    let(:cdict) do
      Zstd::CDict.new(File.read("#{__dir__}/dictionary"), 5)
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      dict_stream = Zstd::StreamingCompress.new(dict: cdict)
      dict_stream << user_json
      dict_res = dict_stream.finish
      stream = Zstd::StreamingCompress.new(level: 5)
      stream << user_json
      res = stream.finish

      expect(dict_res.length).to be < res.length
    end
  end

  describe 'nil dictionary' do
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      dict_stream = Zstd::StreamingCompress.new(level: 5, dict: nil)
      dict_stream << user_json
      dict_res = dict_stream.finish
      stream = Zstd::StreamingCompress.new(level: 5)
      stream << user_json
      res = stream.finish

      expect(dict_res.length).to eq(res.length)
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    describe 'Ractor' do
      it 'should be supported' do
        r = Ractor.new {
          stream = Zstd::StreamingCompress.new(level: 5)
          stream << "abc" << "def"
          res = stream.finish
        }
        expect(Zstd.decompress(r.take)).to eq('abcdef')
      end
    end
  end
end
