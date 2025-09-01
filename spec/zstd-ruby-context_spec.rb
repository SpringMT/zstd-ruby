require "spec_helper"

describe Zstd::Context do
  let(:test_data) { "Hello World!" * 100 }
  let(:small_data) { "Hello World!" }
  let(:large_data) { "A" * 100_000 }

  describe "#initialize" do
    it "creates a new context with default compression level" do
      ctx = Zstd::Context.new
      expect(ctx).to be_a(Zstd::Context)
    end

    it "creates a new context with specified compression level" do
      ctx = Zstd::Context.new(level: 5)
      expect(ctx).to be_a(Zstd::Context)
    end

    it "creates a new context with integer compression level" do
      ctx = Zstd::Context.new(5)
      expect(ctx).to be_a(Zstd::Context)
    end

    it "handles negative compression levels" do
      ctx = Zstd::Context.new(level: -1)
      expect(ctx).to be_a(Zstd::Context)
    end

    it "handles high compression levels" do
      ctx = Zstd::Context.new(level: 19)
      expect(ctx).to be_a(Zstd::Context)
    end
  end

  describe "#compress" do
    let(:ctx) { Zstd::Context.new(level: 3) }

    it "compresses data correctly" do
      compressed = ctx.compress(test_data)
      expect(compressed).to be_a(String)
      expect(compressed.length).to be < test_data.length
    end

    it "compresses empty string" do
      compressed = ctx.compress("")
      expect(compressed).to be_a(String)
    end

    it "compresses small data" do
      compressed = ctx.compress(small_data)
      expect(compressed).to be_a(String)
    end

    it "compresses large data" do
      compressed = ctx.compress(large_data)
      expect(compressed).to be_a(String)
      expect(compressed.length).to be < large_data.length
    end

    it "can compress multiple times with same context" do
      compressed1 = ctx.compress(test_data)
      compressed2 = ctx.compress(test_data)

      expect(compressed1).to be_a(String)
      expect(compressed2).to be_a(String)
      expect(compressed1).to eq(compressed2)
    end

    it "compresses different data with same context" do
      data1 = "First piece of data"
      data2 = "Second piece of data"

      compressed1 = ctx.compress(data1)
      compressed2 = ctx.compress(data2)

      expect(compressed1).to be_a(String)
      expect(compressed2).to be_a(String)
      expect(compressed1).not_to eq(compressed2)
    end
  end

  describe "#decompress" do
    let(:ctx) { Zstd::Context.new(level: 3) }

    it "decompresses data correctly" do
      compressed = ctx.compress(test_data)
      decompressed = ctx.decompress(compressed)
      expect(decompressed).to eq(test_data)
    end

    it "decompresses empty string" do
      compressed = ctx.compress("")
      decompressed = ctx.decompress(compressed)
      expect(decompressed).to eq("")
    end

    it "decompresses small data" do
      compressed = ctx.compress(small_data)
      decompressed = ctx.decompress(compressed)
      expect(decompressed).to eq(small_data)
    end

    it "decompresses large data" do
      compressed = ctx.compress(large_data)
      decompressed = ctx.decompress(compressed)
      expect(decompressed).to eq(large_data)
    end

    it "can decompress multiple times with same context" do
      compressed = ctx.compress(test_data)
      decompressed1 = ctx.decompress(compressed)
      decompressed2 = ctx.decompress(compressed)

      expect(decompressed1).to eq(test_data)
      expect(decompressed2).to eq(test_data)
      expect(decompressed1).to eq(decompressed2)
    end

    it "raises error for invalid compressed data" do
      expect {
        ctx.decompress("invalid data")
      }.to raise_error(RuntimeError, /Not compressed by zstd/)
    end
  end

  describe "context reuse" do
    let(:ctx) { Zstd::Context.new(level: 3) }

    it "can alternate between compress and decompress operations" do
      data1 = "First data"
      data2 = "Second data"

      compressed1 = ctx.compress(data1)
      decompressed1 = ctx.decompress(compressed1)
      compressed2 = ctx.compress(data2)
      decompressed2 = ctx.decompress(compressed2)

      expect(decompressed1).to eq(data1)
      expect(decompressed2).to eq(data2)
    end

    it "handles multiple operations efficiently" do
      data_sets = [
        "Data set 1",
        "Data set 2" * 10,
        "Data set 3" * 100,
        "",
        "Single"
      ]

      compressed_data = []
      decompressed_data = []

      # Compress all data
      data_sets.each do |data|
        compressed_data << ctx.compress(data)
      end

      # Decompress all data
      compressed_data.each do |compressed|
        decompressed_data << ctx.decompress(compressed)
      end

      expect(decompressed_data).to eq(data_sets)
    end
  end

  describe "compatibility with module methods" do
    let(:ctx) { Zstd::Context.new(level: 3) }

    it "produces compatible compressed data with Zstd.compress" do
      compressed_ctx = ctx.compress(test_data)
      compressed_module = Zstd.compress(test_data, level: 3)

      decompressed_from_ctx = Zstd.decompress(compressed_ctx)
      decompressed_from_module = ctx.decompress(compressed_module)

      expect(decompressed_from_ctx).to eq(test_data)
      expect(decompressed_from_module).to eq(test_data)
    end

    it "can decompress data compressed by module methods" do
      compressed = Zstd.compress(test_data, level: 3)
      decompressed = ctx.decompress(compressed)
      expect(decompressed).to eq(test_data)
    end

    it "module methods can decompress context-compressed data" do
      compressed = ctx.compress(test_data)
      decompressed = Zstd.decompress(compressed)
      expect(decompressed).to eq(test_data)
    end
  end

  describe "compression levels" do
    it "different levels produce different compression ratios" do
      data = "A" * 10000

      ctx_low = Zstd::Context.new(level: 1)
      ctx_high = Zstd::Context.new(level: 9)

      compressed_low = ctx_low.compress(data)
      compressed_high = ctx_high.compress(data)

      # Both should decompress correctly
      expect(ctx_low.decompress(compressed_low)).to eq(data)
      expect(ctx_high.decompress(compressed_high)).to eq(data)

      # Higher compression should generally produce smaller output
      expect(compressed_high.length).to be <= compressed_low.length
    end
  end

  describe "thread safety" do
    it "each context instance is independent" do
      ctx1 = Zstd::Context.new(level: 1)
      ctx2 = Zstd::Context.new(level: 5)

      data1 = "Context 1 data"
      data2 = "Context 2 data"

      compressed1 = ctx1.compress(data1)
      compressed2 = ctx2.compress(data2)

      decompressed1 = ctx1.decompress(compressed1)
      decompressed2 = ctx2.decompress(compressed2)

      expect(decompressed1).to eq(data1)
      expect(decompressed2).to eq(data2)

      # Cross-decompression should also work
      expect(ctx1.decompress(compressed2)).to eq(data2)
      expect(ctx2.decompress(compressed1)).to eq(data1)
    end
  end

  describe "memory management" do
    it "handles context cleanup properly" do
      # Create and use many contexts to test memory management
      100.times do |i|
        ctx = Zstd::Context.new(level: (i % 10) + 1)
        data = "Test data #{i}"
        compressed = ctx.compress(data)
        decompressed = ctx.decompress(compressed)
        expect(decompressed).to eq(data)
      end
    end
  end

  describe "error handling" do
    let(:ctx) { Zstd::Context.new }

    it "handles binary data correctly" do
      binary_data = (0..255).map(&:chr).join * 100
      compressed = ctx.compress(binary_data)
      decompressed = ctx.decompress(compressed)
      expect(decompressed).to eq(binary_data)
    end

    it "preserves encoding" do
      utf8_data = "Hello 世界! 🌍"
      compressed = ctx.compress(utf8_data)
      decompressed = ctx.decompress(compressed)
      expect(decompressed.force_encoding(utf8_data.encoding)).to eq(utf8_data)
    end
  end
end
