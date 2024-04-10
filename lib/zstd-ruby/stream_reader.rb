module Zstd
  # @todo Exprimental
  class StreamReader
    def initialize(io)
      @io = io
      @stream = Zstd::StreamingDecompress.new
    end

    def read(length)
      if @io.eof?
        raise StandardError, "EOF"
      end
      data = @io.read(length)
      @stream.decompress(data)
    end

    def close
      @io.write(@stream.finish)
      @io.close
    end
  end
end
