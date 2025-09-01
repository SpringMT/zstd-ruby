require "spec_helper"

describe "Zstd Split Contexts" do
  let(:test_data) { "Hello World!" * 100 }
  let(:small_data) { "Hello World!" }
  let(:large_data) { "A" * 100_000 }

  describe Zstd::CContext do
    describe "#initialize" do
      it "creates a new compression context with default level" do
        ctx = Zstd::CContext.new
        expect(ctx).to be_a(Zstd::CContext)
      end

      it "creates a new compression context with specified level" do
        ctx = Zstd::CContext.new(level: 5)
        expect(ctx).to be_a(Zstd::CContext)
      end

      it "creates a new compression context with integer level" do
        ctx = Zstd::CContext.new(5)
        expect(ctx).to be_a(Zstd::CContext)
      end

      it "handles negative compression levels" do
        ctx = Zstd::CContext.new(level: -1)
        expect(ctx).to be_a(Zstd::CContext)
      end

      it "handles high compression levels" do
        ctx = Zstd::CContext.new(level: 19)
        expect(ctx).to be_a(Zstd::CContext)
      end
    end

    describe "#compress" do
      let(:ctx) { Zstd::CContext.new(level: 3) }

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

      it "is compatible with module decompression" do
        compressed = ctx.compress(test_data)
        decompressed = Zstd.decompress(compressed)
        expect(decompressed).to eq(test_data)
      end
    end

    describe "compression levels" do
      it "different levels produce different compression ratios" do
        data = "A" * 10000

        ctx_low = Zstd::CContext.new(level: 1)
        ctx_high = Zstd::CContext.new(level: 9)

        compressed_low = ctx_low.compress(data)
        compressed_high = ctx_high.compress(data)

        # Both should decompress correctly
        expect(Zstd.decompress(compressed_low)).to eq(data)
        expect(Zstd.decompress(compressed_high)).to eq(data)

        # Higher compression should generally produce smaller output
        expect(compressed_high.length).to be <= compressed_low.length
      end
    end
  end

  describe Zstd::DContext do
    let(:ctx) { Zstd::DContext.new }
    let(:cctx) { Zstd::CContext.new(level: 3) }

    describe "#initialize" do
      it "creates a new decompression context" do
        ctx = Zstd::DContext.new
        expect(ctx).to be_a(Zstd::DContext)
      end

      it "accepts dictionary argument" do
        dict = "sample dictionary data"
        ctx = Zstd::DContext.new(dict)
        expect(ctx).to be_a(Zstd::DContext)
      end
    end

    describe "#decompress" do
      it "decompresses data correctly" do
        compressed = cctx.compress(test_data)
        decompressed = ctx.decompress(compressed)
        expect(decompressed).to eq(test_data)
      end

      it "decompresses empty string" do
        compressed = cctx.compress("")
        decompressed = ctx.decompress(compressed)
        expect(decompressed).to eq("")
      end

      it "decompresses small data" do
        compressed = cctx.compress(small_data)
        decompressed = ctx.decompress(compressed)
        expect(decompressed).to eq(small_data)
      end

      it "decompresses large data" do
        compressed = cctx.compress(large_data)
        decompressed = ctx.decompress(compressed)
        expect(decompressed).to eq(large_data)
      end

      it "can decompress multiple times with same context" do
        compressed = cctx.compress(test_data)
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

      it "is compatible with module compression" do
        compressed = Zstd.compress(test_data, level: 3)
        decompressed = ctx.decompress(compressed)
        expect(decompressed).to eq(test_data)
      end
    end
  end

  describe "Cross-compatibility" do
    let(:cctx) { Zstd::CContext.new(level: 3) }
    let(:dctx) { Zstd::DContext.new }
    let(:unified_ctx) { Zstd::Context.new(level: 3) }

    it "CContext output can be decompressed by DContext" do
      compressed = cctx.compress(test_data)
      decompressed = dctx.decompress(compressed)
      expect(decompressed).to eq(test_data)
    end

    it "all context types produce compatible output" do
      module_compressed = Zstd.compress(test_data, level: 3)
      cctx_compressed = cctx.compress(test_data)
      unified_compressed = unified_ctx.compress(test_data)

      # All should decompress to the same result
      expect(dctx.decompress(module_compressed)).to eq(test_data)
      expect(dctx.decompress(cctx_compressed)).to eq(test_data)
      expect(dctx.decompress(unified_compressed)).to eq(test_data)
      expect(unified_ctx.decompress(cctx_compressed)).to eq(test_data)
      expect(Zstd.decompress(cctx_compressed)).to eq(test_data)
    end

    it "handles mixed workloads efficiently" do
      # Compress different data with CContext
      data1 = "First data set"
      data2 = "Second data set" * 10
      data3 = "Third data set" * 100

      compressed1 = cctx.compress(data1)
      compressed2 = cctx.compress(data2)
      compressed3 = cctx.compress(data3)

      # Decompress with DContext
      expect(dctx.decompress(compressed1)).to eq(data1)
      expect(dctx.decompress(compressed2)).to eq(data2)
      expect(dctx.decompress(compressed3)).to eq(data3)
    end
  end

  describe "Memory efficiency" do
    it "CContext uses less memory than unified Context" do
      # This is a conceptual test - CContext only allocates compression context
      cctx = Zstd::CContext.new(level: 3)
      unified_ctx = Zstd::Context.new(level: 3)

      # Both should work, but CContext should be more memory efficient
      compressed_c = cctx.compress(test_data)
      compressed_unified = unified_ctx.compress(test_data)

      expect(compressed_c).to be_a(String)
      expect(compressed_unified).to be_a(String)
    end

    it "DContext uses less memory than unified Context" do
      # This is a conceptual test - DContext only allocates decompression context
      compressed_data = Zstd.compress(test_data, level: 3)

      dctx = Zstd::DContext.new
      unified_ctx = Zstd::Context.new(level: 3)

      # Both should work, but DContext should be more memory efficient
      decompressed_d = dctx.decompress(compressed_data)
      decompressed_unified = unified_ctx.decompress(compressed_data)

      expect(decompressed_d).to eq(test_data)
      expect(decompressed_unified).to eq(test_data)
    end
  end

  describe "Error handling" do
    let(:cctx) { Zstd::CContext.new }
    let(:dctx) { Zstd::DContext.new }

    it "handles binary data correctly" do
      binary_data = (0..255).map(&:chr).join * 100
      compressed = cctx.compress(binary_data)
      decompressed = dctx.decompress(compressed)
      expect(decompressed).to eq(binary_data)
    end

    it "handles UTF-8 data correctly" do
      utf8_data = "Hello 世界! 🌍"
      compressed = cctx.compress(utf8_data)
      decompressed = dctx.decompress(compressed)
      expect(decompressed.force_encoding(utf8_data.encoding)).to eq(utf8_data)
    end
  end

  describe "Performance characteristics" do
    let(:medium_data) { "A" * 10_000 }

    it "contexts can be reused efficiently" do
      cctx = Zstd::CContext.new(level: 3)
      dctx = Zstd::DContext.new

      # Multiple compression operations
      compressed_results = []
      10.times do |i|
        data = "#{medium_data}_#{i}"
        compressed_results << cctx.compress(data)
      end

      # Multiple decompression operations
      decompressed_results = []
      compressed_results.each do |compressed|
        decompressed_results << dctx.decompress(compressed)
      end

      # Verify all operations succeeded
      expect(decompressed_results.length).to eq(10)
      decompressed_results.each_with_index do |result, i|
        expect(result).to eq("#{medium_data}_#{i}")
      end
    end
  end
end
