# spec/streaming_128kb_cliff_spec.rb
require "spec_helper"
require "stringio"
require "zstd-ruby"

RSpec.describe "Zstd streaming 128KB cliff" do
  MAGIC = [0x28, 0xB5, 0x2F, 0xFD].freeze

  def hex(str)
    str.unpack1("H*")
  end

  def has_magic?(bin)
    bytes = bin.bytes
    bytes[0, 4] == MAGIC
  end

  shared_examples "round-trip streaming compress" do |size|
    it "round-trips #{size} bytes and starts with zstd magic" do
      # Produce data
      src = "a" * size

      sc = Zstd::StreamingCompress.new
      sc << src
      compressed = sc.finish

      expect(has_magic?(compressed)).to be(true), "missing magic: #{hex(compressed)[0, 16]}"
      expect(Zstd.decompress(compressed)).to eq(src)
    end
  end

  context "exactly around 128 KiB" do
    include_examples "round-trip streaming compress", 131_071
    include_examples "round-trip streaming compress", 131_072     # the cliff
    include_examples "round-trip streaming compress", 131_073
  end

  context "multiple writes crossing the boundary" do
    it "64KiB + 64KiB (exact boundary) works" do
      part = "x" * 65_536
      sc = Zstd::StreamingCompress.new
      sc << part
      sc << part
      compressed = sc.finish
      expect(has_magic?(compressed)).to be(true)
      expect(Zstd.decompress(compressed)).to eq(part * 2)
    end

    it "64KiB + 64KiB + 1 works" do
      a = "a" * 65_536
      b = "b" * 65_536
      c = "c"
      sc = Zstd::StreamingCompress.new
      sc << a << b << c
      compressed = sc.finish
      expect(has_magic?(compressed)).to be(true)
      expect(Zstd.decompress(compressed)).to eq(a + b + c)
    end
  end

  context "flush/end draining" do
    it "returns all produced bytes across flush and finish" do
      sc = Zstd::StreamingCompress.new
      sc << ("a" * 70_000)
      out = sc.flush
      expect(out).not_to be_empty
      sc << ("b" * 70_000)
      out << sc.finish
      expect(has_magic?(out)).to be(true)
      expect(Zstd.decompress(out)).to eq(("a" * 70_000) + ("b" * 70_000))
    end
  end

  context "GC.compact interaction" do
    it "survives compaction around the boundary" do
      sc = Zstd::StreamingCompress.new
      sc << ("a" * 80_000)
      GC.compact if GC.respond_to?(:compact)
      sc << ("b" * 60_000) # total now > 128KiB
      compressed = sc.finish
      expect(has_magic?(compressed)).to be(true)
      expect(Zstd.decompress(compressed)).to eq(("a" * 80_000) + ("b" * 60_000))
    end
  end

  context "larger payload sanity" do
    it "round-trips ~1 MiB" do
      src = "z" * 1_048_576
      sc = Zstd::StreamingCompress.new(level: 3)
      sc << src
      compressed = sc.finish
      expect(has_magic?(compressed)).to be(true)
      expect(Zstd.decompress(compressed)).to eq(src)
    end
  end

  describe Zstd::StreamWriter do
    it "produces a valid frame and round-trips at exactly 128KiB" do
      io = StringIO.new
      sw = Zstd::StreamWriter.new(io)
      sw.write("a" * 131_072)
      sw.finish

      io.rewind
      bin = io.read
      expect(has_magic?(bin)).to be(true), "missing magic: #{hex(bin)[0, 16]}"

      io.rewind
      sr = Zstd::StreamReader.new(io)
      out = sr.read(2_000_000)
      expect(out.size).to eq(131_072)
      expect(out).to eq("a" * 131_072)
      io.close
    end

    it "handles boundary-crossing writes with flush in between" do
      io = StringIO.new
      sw = Zstd::StreamWriter.new(io)
      sw.write("a" * 70_000)
      sw.write("b" * 70_000) # crosses 128KiB internally
      sw.finish

      io.rewind
      bin = io.read
      expect(has_magic?(bin)).to be(true)
      io.rewind
      sr = Zstd::StreamReader.new(io)
      out = sr.read(1_000_000)
      expect(out).to eq("a" * 70_000 + "b" * 70_000)
      io.close
    end

    it "survives GC.compact mid-stream" do
      io = StringIO.new
      sw = Zstd::StreamWriter.new(io)
      sw.write("x" * 90_000)
      GC.compact if GC.respond_to?(:compact)
      sw.write("y" * 50_000)
      sw.finish

      io.rewind
      bin = io.read
      expect(has_magic?(bin)).to be(true)
      io.rewind
      sr = Zstd::StreamReader.new(io)
      out = sr.read(200_000)
      expect(out).to eq("x" * 90_000 + "y" * 50_000)
    end
  end
end
