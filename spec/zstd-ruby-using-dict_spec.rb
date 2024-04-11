require "spec_helper"
require 'zstd-ruby'
require 'securerandom'

# Generate dictionay methods
# https://github.com/facebook/zstd#the-case-for-small-data-compression
# https://github.com/facebook/zstd/releases/tag/v1.1.3

RSpec.describe Zstd do
  describe 'compress and decompress with dict keyward args' do
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end

    it 'should work' do
      compressed_using_dict = Zstd.compress(user_json, dict: dictionary)
      compressed = Zstd.compress(user_json)
      expect(compressed_using_dict.length).to be < compressed.length
      expect(user_json).to eq(Zstd.decompress(compressed_using_dict, dict: dictionary))
    end

    it 'should work with simple string' do
      compressed_using_dict = Zstd.compress("abc", dict: dictionary)
      expect("abc").to eq(Zstd.decompress(compressed_using_dict, dict: dictionary))
    end

    it 'should work with blank input' do
      compressed_using_dict = Zstd.compress("", dict: dictionary)
      expect("").to eq(Zstd.decompress(compressed_using_dict, dict: dictionary))
    end

    it 'should work with blank dictionary' do
      compressed_using_dict = Zstd.compress(user_json, dict: "")
      expect(user_json).to eq(Zstd.decompress(compressed_using_dict, dict: ""))
      expect(user_json).to eq(Zstd.decompress(compressed_using_dict))
    end

    it 'should support compression levels' do
      compressed_using_dict    = Zstd.compress(user_json, dict: dictionary)
      compressed_using_dict_10 = Zstd.compress(user_json, dict: dictionary, level: 10)
      expect(compressed_using_dict_10.length).to be < compressed_using_dict.length
      expect(user_json).to eq(Zstd.decompress(compressed_using_dict_10, dict: dictionary))
    end

    it 'should support compression levels with blank dictionary' do
      compressed_using_dict_10 = Zstd.compress_using_dict(user_json, dict: dictionary, level: 10)
      expect(user_json).to eq(Zstd.decompress(compressed_using_dict_10, dict: ""))
      expect(user_json).to eq(Zstd.decompress(compressed_using_dict_10))
    end
  end

  describe 'compress_using_dict' do
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end

    it 'should work' do
      compressed_using_dict = Zstd.compress_using_dict(user_json, dictionary)
      compressed = Zstd.compress(user_json)
      expect(compressed_using_dict.length).to be < compressed.length
      expect(user_json).to eq(Zstd.decompress_using_dict(compressed_using_dict, dictionary))
    end

    it 'should work with simple string' do
      compressed_using_dict = Zstd.compress_using_dict("abc", dictionary)
      expect("abc").to eq(Zstd.decompress_using_dict(compressed_using_dict, dictionary))
    end

    it 'should work with blank input' do
      compressed_using_dict = Zstd.compress_using_dict("", dictionary)
      expect("").to eq(Zstd.decompress_using_dict(compressed_using_dict, dictionary))
    end

    it 'should work with blank dictionary' do
      compressed_using_dict = Zstd.compress_using_dict(user_json, "")
      expect(user_json).to eq(Zstd.decompress_using_dict(compressed_using_dict, ""))
      expect(user_json).to eq(Zstd.decompress(compressed_using_dict))
    end

    it 'should support compression levels' do
      compressed_using_dict    = Zstd.compress_using_dict(user_json, dictionary)
      compressed_using_dict_10 = Zstd.compress_using_dict(user_json, dictionary, 10)
      expect(compressed_using_dict_10.length).to be < compressed_using_dict.length
      expect(user_json).to eq(Zstd.decompress_using_dict(compressed_using_dict_10, dictionary))
    end

    it 'should support compression levels with blank dictionary' do
      compressed_using_dict_10 = Zstd.compress_using_dict(user_json, "", 10)
      expect(user_json).to eq(Zstd.decompress_using_dict(compressed_using_dict_10, ""))
      expect(user_json).to eq(Zstd.decompress(compressed_using_dict_10))
    end
  end

end
