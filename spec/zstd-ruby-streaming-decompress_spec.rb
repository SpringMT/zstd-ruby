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

  describe 'Zstd::DDict dictionary the caller does not keep' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'stays alive as long as the stream that references it' do
      compressed_json = Zstd.compress(user_json, dict: dictionary)
      # The DDict is never stored anywhere: the stream is its only reference.
      stream = Zstd::StreamingDecompress.new(dict: Zstd::DDict.new(dictionary))
      GC.start
      GC.compact
      1000.times { |i| "fill the slot the DDict would have freed #{i}" }
      GC.start

      result = +''
      result << stream.decompress(compressed_json[0, 5])
      result << stream.decompress(compressed_json[5..-1])
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

  describe 'frame_complete?' do
    # Written by the zstd command line tool, which adds a checksum of the
    # content to the end of each frame by default:
    #   ruby -e 'print "foo bar buzz " * 10' | zstd -c
    # The magic number (4 bytes), frame header (2), block header (3),
    # compressed block (20) and content checksum (4).
    let(:frame) { ['28b52ffd0458a5000068666f6f206261722062757a7a20010012d2f905b7745bfe'].pack('H*') }
    let(:content) { 'foo bar buzz ' * 10 }

    it 'is true before any input' do
      stream = Zstd::StreamingDecompress.new
      expect(stream.frame_complete?).to eq(true)
      expect(stream.decompress('')).to eq('')
      expect(stream.decompress_with_pos('')).to eq(['', 0])
      expect(stream.frame_complete?).to eq(true)
    end

    it 'is true when the input ends at the end of a frame' do
      stream = Zstd::StreamingDecompress.new
      expect(stream.decompress(frame)).to eq(content)
      expect(stream.frame_complete?).to eq(true)
    end

    {
      'within the magic number' => 2,
      'within the frame header' => 5,
      'within a block header' => 7,
      'within a block' => 15,
      'right before the checksum' => 29,
      'within the checksum' => 31
    }.each do |where, length|
      it "is false when the input ends #{where}" do
        stream = Zstd::StreamingDecompress.new
        result = stream.decompress(frame.byteslice(0, length))
        expect(stream.frame_complete?).to eq(false)

        result << stream.decompress(frame.byteslice(length..-1))
        expect(result).to eq(content)
        expect(stream.frame_complete?).to eq(true)
      end
    end

    it 'is false when the input ends between two blocks' do
      compress = Zstd::StreamingCompress.new
      # flush ends a block, so that all the data so far can be decompressed
      head = compress.compress('abc' * 1000) + compress.flush
      tail = compress.compress('def') + compress.finish

      stream = Zstd::StreamingDecompress.new
      expect(stream.decompress(head)).to eq('abc' * 1000)
      expect(stream.frame_complete?).to eq(false)
      expect(stream.decompress(tail)).to eq('def')
      expect(stream.frame_complete?).to eq(true)
    end

    it 'is true only at the end of each of several frames' do
      skippable = [0x184D2A50, 8].pack('VV') + 'metadata'
      frames = [Zstd.compress('Hello, '), frame, skippable, Zstd.compress(''), Zstd.compress('World!')]
      input = frames.join
      ends = frames.each_with_object([]) { |f, sums| sums << (sums.last || 0) + f.bytesize }

      # One byte at a time, so that the input ends at every position.
      stream = Zstd::StreamingDecompress.new
      stream_with_pos = Zstd::StreamingDecompress.new
      result = ''
      input.bytesize.times do |pos|
        byte = input.byteslice(pos, 1)
        result << stream.decompress(byte)
        expect(stream_with_pos.decompress_with_pos(byte)[1]).to eq(1)

        expected = ends.include?(pos + 1)
        expect(stream.frame_complete?).to eq(expected), "decompress after #{pos + 1} bytes"
        expect(stream_with_pos.frame_complete?).to eq(expected), "decompress_with_pos after #{pos + 1} bytes"
      end
      expect(result).to eq('Hello, ' + content + 'World!')
    end

    it 'is false when the input ends within a later frame' do
      last = Zstd.compress('World!')
      input = Zstd.compress('Hello, ') + frame + last

      stream = Zstd::StreamingDecompress.new
      # 5 bytes into the last frame: its magic number and frame header descriptor
      expect(stream.decompress(input.byteslice(0, input.bytesize - last.bytesize + 5))).to eq('Hello, ' + content)
      expect(stream.frame_complete?).to eq(false)

      stream = Zstd::StreamingDecompress.new
      expect(stream.decompress(input)).to eq('Hello, ' + content + 'World!')
      expect(stream.frame_complete?).to eq(true)
    end

    it 'stays true after calls with empty input' do
      stream = Zstd::StreamingDecompress.new
      stream.decompress(frame)
      3.times do
        expect(stream.decompress('')).to eq('')
        expect(stream.decompress_with_pos('')).to eq(['', 0])
        expect(stream.frame_complete?).to eq(true)
      end
    end

    it 'is false until decompress_with_pos has returned all the output of a frame' do
      # decompress_with_pos returns at most ZSTD_DStreamOutSize (128 KiB) per call.
      data = 'a' * 1_000_000
      input = Zstd.compress(data)
      stream = Zstd::StreamingDecompress.new
      result = ''
      until input.empty?
        output, consumed = stream.decompress_with_pos(input)
        result << output
        input = input.byteslice(consumed..-1)
        expect(stream.frame_complete?).to eq(result.bytesize == data.bytesize)
      end
      expect(result).to eq(data)
    end

    it 'is false after the input fails to decompress' do
      stream = Zstd::StreamingDecompress.new
      stream.decompress(frame)
      expect { stream.decompress('not zstd') }.to raise_error(RuntimeError)
      expect(stream.frame_complete?).to eq(false)
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
