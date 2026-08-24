require "spec_helper"
require 'zstd-ruby'
require 'stringio'

RSpec.describe Zstd::StreamReader do
  # Compressible payload large enough to span several internal zstd blocks.
  let(:compressible) { (1..20_000).map { |n| %({"name":"pkg-#{n}","version":"1.0.#{n}"}) }.join("\n") << "\n" }
  # Incompressible payload: compressed size ends up close to the original size.
  let(:incompressible) { Random.new(42).bytes(512 * 1024) }

  def reader_for(data, **opts)
    described_class.new(StringIO.new(Zstd.compress(data)), **opts)
  end

  def read_all(reader, length)
    +''.b.tap do |out|
      while (chunk = reader.read(length))
        out << chunk
      end
    end
  end

  describe '#read' do
    it 'reads the data written by StreamWriter' do
      io = StringIO.new
      writer = Zstd::StreamWriter.new(io)
      writer.write("abc")
      writer.write("def")
      writer.finish
      io.rewind

      reader = described_class.new(io)
      expect(reader.read(10)).to eq('abcdef')
      expect(reader.read(10)).to be_nil
    end

    it 'returns exactly the requested number of decompressed bytes' do
      reader = reader_for(compressible)

      5.times { expect(reader.read(512).bytesize).to eq(512) }
    end

    it 'returns the requested length regardless of the compression ratio' do
      # A tiny compressed frame expands to far more than the requested length;
      # the reader must not hand back the whole frame at once.
      reader = reader_for("hello world\n" * 20_000)

      expect(reader.read(512).bytesize).to eq(512)
    end

    it 'round-trips compressible data' do
      expect(read_all(reader_for(compressible), 512)).to eq(compressible)
    end

    it 'round-trips incompressible data' do
      expect(read_all(reader_for(incompressible), 4096)).to eq(incompressible)
    end

    it 'round-trips data smaller than a single read' do
      expect(read_all(reader_for('sample data'), 4096)).to eq('sample data')
    end

    it 'returns a short final read rather than padding' do
      reader = reader_for('0123456789')

      expect(reader.read(4)).to eq('0123')
      expect(reader.read(100)).to eq('456789')
      expect(reader.read(100)).to be_nil
    end

    it 'returns nil once the stream is exhausted' do
      reader = reader_for('sample data')
      reader.read(4096)

      expect(reader.read(4096)).to be_nil
      expect(reader.read(4096)).to be_nil
    end

    it 'reads the whole stream when no length is given' do
      expect(reader_for(compressible).read).to eq(compressible)
    end

    it 'returns an empty String at EOF when no length is given' do
      reader = reader_for('sample data')
      reader.read

      expect(reader.read).to eq('')
    end

    it 'returns an empty String for a zero length' do
      expect(reader_for('sample data').read(0)).to eq('')
    end

    it 'raises ArgumentError for a negative length' do
      expect { reader_for('sample data').read(-1) }.to raise_error(ArgumentError)
    end

    it 'writes into outbuf when given' do
      reader = reader_for(compressible)
      outbuf = +'previous contents'

      result = reader.read(512, outbuf)

      expect(result).to equal(outbuf)
      expect(outbuf.bytesize).to eq(512)
    end

    it 'clears outbuf and returns nil at EOF' do
      reader = reader_for('sample data')
      reader.read(4096)
      outbuf = +'previous contents'

      expect(reader.read(4096, outbuf)).to be_nil
      expect(outbuf).to be_empty
    end

    it 'honours a custom chunk_size' do
      reader = reader_for(compressible, chunk_size: 1024)

      expect(read_all(reader, 512)).to eq(compressible)
    end

    it 'rejects a non-positive chunk_size' do
      expect { reader_for('sample data', chunk_size: 0) }.to raise_error(ArgumentError)
    end
  end

  describe '#eof?' do
    it 'is false while data remains and true once drained' do
      reader = reader_for('sample data')

      expect(reader.eof?).to eq(false)
      expect(reader.read(4096)).to eq('sample data')
      expect(reader.eof?).to eq(true)
    end

    it 'does not consume data' do
      reader = reader_for('sample data')

      expect(reader.eof?).to eq(false)
      expect(reader.read(4096)).to eq('sample data')
    end
  end

  describe '#close' do
    it 'closes the underlying IO' do
      io = StringIO.new(Zstd.compress('sample data'))
      reader = described_class.new(io)

      expect { reader.close }.not_to raise_error
      expect(io).to be_closed
    end
  end

  describe 'driving an IO consumer' do
    it 'can be wrapped to feed Gem::Package::TarReader' do
      require 'rubygems/package'

      tar = StringIO.new
      Gem::Package::TarWriter.new(tar) do |writer|
        3.times { |i| writer.add_file("0#{i}.txt", 0644) { |f| f.write(compressible) } }
      end

      io_like = Class.new do
        def initialize(reader)
          @reader = reader
          @pos = 0
        end

        attr_reader :pos

        def read(length = nil, outbuf = nil)
          data = @reader.read(length, outbuf)
          @pos += data.bytesize if data
          data
        end

        def eof?
          @reader.eof?
        end

        def seek(amount, whence = IO::SEEK_SET)
          raise Errno::EINVAL unless whence == IO::SEEK_CUR

          while amount > 0
            chunk = read(amount < 65_536 ? amount : 65_536)
            break unless chunk

            amount -= chunk.bytesize
          end
          0
        end
      end

      entries = []
      source = StringIO.new(Zstd.compress(tar.string))
      Gem::Package::TarReader.new(io_like.new(described_class.new(source))) do |reader|
        reader.each { |entry| entries << [entry.full_name, entry.read.bytesize] }
      end

      expect(entries).to eq(3.times.map { |i| ["0#{i}.txt", compressible.bytesize] })
    end
  end
end
