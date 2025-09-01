require "spec_helper"

describe "Zstd Dictionary Context Support" do
  let(:test_data) { "This is sample data for dictionary testing. It contains repeated patterns and common phrases that should compress well with a dictionary." }
  let(:dictionary) do
    # Create a simple dictionary from repeated patterns
    "sample data dictionary testing patterns phrases compress well common repeated"
  end

  describe Zstd::CContext do
    describe "dictionary support" do
      it "creates context with dictionary using hash syntax" do
        ctx = Zstd::CContext.new(level: 3, dict: dictionary)
        expect(ctx).to be_a(Zstd::CContext)
      end

      it "creates context with dictionary using positional arguments" do
        ctx = Zstd::CContext.new(3, dictionary)
        expect(ctx).to be_a(Zstd::CContext)
      end

      it "compresses data using dictionary" do
        ctx = Zstd::CContext.new(level: 3, dict: dictionary)
        compressed = ctx.compress(test_data)
        expect(compressed).to be_a(String)
        expect(compressed.length).to be < test_data.length
      end

      it "produces smaller output with dictionary than without" do
        ctx_with_dict = Zstd::CContext.new(level: 3, dict: dictionary)
        ctx_without_dict = Zstd::CContext.new(level: 3)

        compressed_with_dict = ctx_with_dict.compress(test_data)
        compressed_without_dict = ctx_without_dict.compress(test_data)

        # Dictionary should produce better compression for data with matching patterns
        expect(compressed_with_dict.length).to be <= compressed_without_dict.length
      end

      it "can compress multiple times with same dictionary context" do
        ctx = Zstd::CContext.new(level: 3, dict: dictionary)

        compressed1 = ctx.compress(test_data)
        compressed2 = ctx.compress(test_data + " additional data")

        expect(compressed1).to be_a(String)
        expect(compressed2).to be_a(String)
        expect(compressed1).not_to eq(compressed2)
      end

      it "works with empty dictionary" do
        ctx = Zstd::CContext.new(level: 3, dict: "")
        compressed = ctx.compress(test_data)
        expect(compressed).to be_a(String)
      end
    end
  end

  describe Zstd::DContext do
    let(:cctx) { Zstd::CContext.new(level: 3, dict: dictionary) }
    let(:compressed_data) { cctx.compress(test_data) }

    describe "dictionary support" do
      it "creates context with dictionary using hash syntax" do
        ctx = Zstd::DContext.new(dict: dictionary)
        expect(ctx).to be_a(Zstd::DContext)
      end

      it "creates context with dictionary using positional argument" do
        ctx = Zstd::DContext.new(dictionary)
        expect(ctx).to be_a(Zstd::DContext)
      end

      it "decompresses data using dictionary" do
        ctx = Zstd::DContext.new(dict: dictionary)
        decompressed = ctx.decompress(compressed_data)
        expect(decompressed).to eq(test_data)
      end

      it "can decompress multiple times with same dictionary context" do
        ctx = Zstd::DContext.new(dict: dictionary)

        decompressed1 = ctx.decompress(compressed_data)
        decompressed2 = ctx.decompress(compressed_data)

        expect(decompressed1).to eq(test_data)
        expect(decompressed2).to eq(test_data)
      end

      it "works with empty dictionary" do
        cctx_empty = Zstd::CContext.new(level: 3, dict: "")
        compressed_empty_dict = cctx_empty.compress(test_data)

        ctx = Zstd::DContext.new(dict: "")
        decompressed = ctx.decompress(compressed_empty_dict)
        expect(decompressed).to eq(test_data)
      end

      it "fails with wrong dictionary" do
        wrong_dict = "completely different dictionary content that does not match"
        ctx = Zstd::DContext.new(dict: wrong_dict)

        expect {
          ctx.decompress(compressed_data)
        }.to raise_error(RuntimeError, /Decompress error/)
      end
    end
  end

  describe "Cross-context compatibility" do
    it "CContext with dict can be decompressed by DContext with same dict" do
      cctx = Zstd::CContext.new(level: 3, dict: dictionary)
      dctx = Zstd::DContext.new(dict: dictionary)

      compressed = cctx.compress(test_data)
      decompressed = dctx.decompress(compressed)

      expect(decompressed).to eq(test_data)
    end

    it "works with module methods and dictionaries" do
      cctx = Zstd::CContext.new(level: 3, dict: dictionary)
      compressed = cctx.compress(test_data)

      # Should be compatible with module dictionary decompression
      decompressed = Zstd.decompress(compressed, dict: dictionary)
      expect(decompressed).to eq(test_data)
    end

    it "module dictionary compression can be decompressed by DContext" do
      compressed = Zstd.compress(test_data, level: 3, dict: dictionary)

      dctx = Zstd::DContext.new(dict: dictionary)
      decompressed = dctx.decompress(compressed)

      expect(decompressed).to eq(test_data)
    end
  end

  describe "Ruby Context with dictionaries" do
    it "supports dictionaries in unified Context class" do
      # This should work once Ruby Context supports dictionary options
      expect {
        ctx = Zstd::Context.new(level: 3, dict: dictionary)
        compressed = ctx.compress(test_data)
        decompressed = ctx.decompress(compressed)
        expect(decompressed).to eq(test_data)
      }.not_to raise_error
    end
  end

  describe "Performance with dictionaries" do
    it "context reuse with dictionaries is efficient" do
      cctx = Zstd::CContext.new(level: 3, dict: dictionary)
      dctx = Zstd::DContext.new(dict: dictionary)

      # Multiple operations should work efficiently
      10.times do |i|
        data = "#{test_data} iteration #{i}"
        compressed = cctx.compress(data)
        decompressed = dctx.decompress(compressed)
        expect(decompressed).to eq(data)
      end
    end
  end

  describe "Error handling" do
    it "handles invalid dictionary gracefully" do
      expect {
        Zstd::CContext.new(level: 3, dict: nil)
      }.not_to raise_error
    end

    it "raises error for non-string dictionary" do
      expect {
        Zstd::CContext.new(level: 3, dict: 12345)
      }.to raise_error(TypeError)
    end
  end
end
