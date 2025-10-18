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

  describe 'decompress_with_pos' do
    it 'should return decompressed data and consumed input position' do
      str = "hello world test data"
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      
      # Test with partial input
      result_array = stream.decompress_with_pos(cstr[0, 10])
      expect(result_array).to be_an(Array)
      expect(result_array.length).to eq(2)
      
      decompressed_data = result_array[0]
      consumed_bytes = result_array[1]
      
      expect(decompressed_data).to be_a(String)
      expect(consumed_bytes).to be_a(Integer)
      expect(consumed_bytes).to be > 0
      expect(consumed_bytes).to be <= 10
    end

    it 'should work with complete compressed data' do
      str = "foo bar buzz"
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      
      result_array = stream.decompress_with_pos(cstr)
      decompressed_data = result_array[0]
      consumed_bytes = result_array[1]
      
      expect(decompressed_data).to eq(str)
      expect(consumed_bytes).to eq(cstr.length)
    end

    it 'should work with multiple calls' do
      str = "test data for multiple calls"
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      
      result = ''
      total_consumed = 0
      chunk_size = 5
      
      while total_consumed < cstr.length
        remaining_data = cstr[total_consumed..-1]
        chunk = remaining_data[0, chunk_size]
        
        result_array = stream.decompress_with_pos(chunk)
        decompressed_chunk = result_array[0]
        consumed_bytes = result_array[1]
        
        result << decompressed_chunk
        total_consumed += consumed_bytes
        
        expect(consumed_bytes).to be > 0
        expect(consumed_bytes).to be <= chunk.length
        
        # If we consumed less than the chunk size, we might be done or need more data
        break if consumed_bytes < chunk.length && total_consumed == cstr.length
      end
      
      expect(result).to eq(str)
      expect(total_consumed).to eq(cstr.length)
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

  describe 'String dictionary streaming decompress + GC.compact' do
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

  describe 'Zstd::DDict dictionary streaming decompress + GC.compact' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:ddict) do
      Zstd::DDict.new(dictionary)
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      compressed_json = Zstd.compress(user_json, dict: dictionary)
      stream = Zstd::StreamingDecompress.new(dict: ddict)
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
        # Ractor#take was replaced at Ruby 3.5.
        # https://bugs.ruby-lang.org/issues/21262
        result = r.respond_to?(:take) ? r.take : r.value

        expect(result).to eq('foo bar buzz')
      end
    end
  end
end
