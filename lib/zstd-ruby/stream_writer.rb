module Zstd
  # @todo Exprimental
  class StreamWriter
    def initialize(io, level: nil)
      @io = io
      @stream = Zstd::StreamingCompress.new(level: level)
    end

    def write(*data)
      @stream.write(*data)
      @io.write(@stream.flush)
    end

    def finish
      @io.write(@stream.finish)
    end

    def close
      @io.write(@stream.finish)
      @io.close
    end
  end
end
