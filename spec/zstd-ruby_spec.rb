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
      large_string = Random.bytes((1<<17) + 15)
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

    context 'with checksum' do
      # Content_Checksum_flag: bit 2 of the frame header descriptor, the byte
      # after the magic number.
      def checksum_flag?(frame)
        frame.getbyte(4) & 0x04 != 0
      end

      # Flips a bit in the middle of the frame.
      def corrupt(frame)
        corrupted = frame.dup
        middle = corrupted.bytesize / 2
        corrupted.setbyte(middle, corrupted.getbyte(middle) ^ 1)
        corrupted
      end

      it 'should not write a checksum by default' do
        compressed = Zstd.compress(user_json)
        expect(checksum_flag?(compressed)).to eq(false)
        expect(Zstd.compress(user_json, checksum: false)).to eq(compressed)
        expect(Zstd.compress(user_json, checksum: nil)).to eq(compressed)
      end

      it 'should add a checksum of the content to the end of the frame' do
        compressed = Zstd.compress('abc', checksum: true)
        expect(checksum_flag?(compressed)).to eq(true)
        # The low 4 bytes of XXH64('abc'), 0x44BC2CF5AD770999, little endian,
        # as the zstd command line tool writes them.
        expect(compressed.byteslice(-4, 4)).to eq("\x99\x09\x77\xAD".b)
        expect(Zstd.decompress(compressed)).to eq('abc')

        compressed = Zstd.compress(user_json, level: 5, checksum: true)
        expect(compressed.bytesize).to eq(Zstd.compress(user_json, level: 5).bytesize + 4)
        expect(Zstd.decompress(compressed)).to eq(user_json)
      end

      it 'should add a checksum with a dictionary' do
        dictionary = File.read("#{__dir__}/dictionary")
        [dictionary, Zstd::CDict.new(dictionary)].each do |dict|
          compressed = Zstd.compress(user_json, dict: dict, checksum: true)
          expect(checksum_flag?(compressed)).to eq(true)
          expect(Zstd.decompress(compressed, dict: dictionary)).to eq(user_json)
        end
      end

      it 'should detect corrupted content on decompress' do
        # Incompressible data is stored as is, so the flipped bit changes the
        # content without breaking the frame: only the checksum can detect it.
        data = Random.new(42).bytes(1000)
        expect(Zstd.decompress(corrupt(Zstd.compress(data)))).not_to eq(data)

        corrupted = corrupt(Zstd.compress(data, checksum: true))
        expect { Zstd.decompress(corrupted) }.to raise_error(RuntimeError, /checksum/)
        expect { Zstd::StreamingDecompress.new.decompress(corrupted) }.to raise_error(RuntimeError, /checksum/)
      end

      it 'should raise ArgumentError unless true or false' do
        expect { Zstd.compress(user_json, checksum: 1) }.to raise_error(ArgumentError)
        expect { Zstd.compress(user_json, checksum: 'true') }.to raise_error(ArgumentError)
      end
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

    it 'should decompress concatenated frames' do
      a = Zstd.compress("Hello, ")
      b = Zstd.compress("World!")
      expect(Zstd.decompress(a + b)).to eq("Hello, World!")
    end

    it 'should decompress three or more concatenated frames' do
      a = Zstd.compress("Hello, ")
      b = Zstd.compress("World!")
      c = Zstd.compress("!!!")
      expect(Zstd.decompress(a + b + c)).to eq("Hello, World!!!!")
    end

    it 'should raise exception with unsupported object' do
      expect { Zstd.decompress(Object.new) }.to raise_error(TypeError)
    end

    it 'should raise (not hang) on a truncated frame' do
      full = Zstd.compress('a' * 2000)
      [
        "\x28\xB5\x2F\xFD".b, # bare zstd magic, no body
        full.byteslice(0, 5),
        full.byteslice(0, 6),
        full.byteslice(0, full.bytesize / 2),
      ].each do |truncated|
        expect { Zstd.decompress(truncated) }.to raise_error(RuntimeError)
      end
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
        # Ractor#take was replaced at Ruby 3.5.
        # https://bugs.ruby-lang.org/issues/21262
        result = r.respond_to?(:take) ? r.take : r.value

        expect(Zstd.decompress(result)).to eq('abc')
      end
    end
  end
end
