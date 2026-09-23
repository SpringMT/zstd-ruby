module Zstd
  # @todo Experimental
  #
  # Wraps a readable IO containing zstd-compressed data and exposes the
  # decompressed bytes through a standard read interface.
  #
  #   File.open('data.zst') do |file|
  #     reader = Zstd::StreamReader.new(file)
  #     while (chunk = reader.read(16 * 1024))
  #       # ...
  #     end
  #   end
  #
  # +length+ is a number of *decompressed* bytes, and +read+ returns +nil+ once
  # the stream is exhausted, so the reader can drive any consumer that expects
  # an IO-like object.
  class StreamReader
    # Number of compressed bytes pulled from the underlying IO per refill.
    DEFAULT_CHUNK_SIZE = 64 * 1024

    def initialize(io, chunk_size: DEFAULT_CHUNK_SIZE)
      raise ArgumentError, "chunk_size must be positive" unless chunk_size.to_int > 0

      @io = io
      @chunk_size = chunk_size.to_int
      @stream = Zstd::StreamingDecompress.new
      @buffer = +''.b
      @pending = +''.b
      @source_eof = false
    end

    # Reads and returns up to +length+ decompressed bytes, or every remaining
    # byte when +length+ is nil.
    #
    # Returns nil at the end of the stream, or an empty String when +length+ is
    # zero, mirroring IO#read.
    def read(length = nil, outbuf = nil)
      if length.nil?
        fill_until(Float::INFINITY)
        data = @buffer
        @buffer = +''.b
        return outbuf ? outbuf.replace(data) : data
      end

      length = length.to_int
      raise ArgumentError, "negative length #{length} given" if length < 0
      return outbuf ? outbuf.replace(+''.b) : +''.b if length == 0

      fill_until(length)
      if @buffer.empty?
        outbuf&.replace(+''.b)
        return nil
      end

      data = @buffer.byteslice(0, length)
      @buffer = @buffer.byteslice(data.bytesize..) || +''.b
      outbuf ? outbuf.replace(data) : data
    end

    def eof?
      fill_until(1)
      @buffer.empty?
    end
    alias_method :eof, :eof?

    def close
      @io.close
      nil
    end

    private

    def fill_until(n)
      while @buffer.bytesize < n
        if @pending.empty?
          break if @source_eof

          chunk = @io.read(@chunk_size)
          if chunk.nil? || chunk.empty?
            @source_eof = true
            break
          end
          @pending = chunk
        end

        # decompress_with_pos writes at most ZSTD_DStreamOutSize bytes per call
        # and reports how much input it consumed, so a high compression ratio
        # cannot balloon the buffer the way decompress would.
        decompressed, consumed = @stream.decompress_with_pos(@pending)
        @pending = @pending.byteslice(consumed..) || +''.b
        @buffer << decompressed

        # No forward progress: the frame is truncated or complete.
        break if consumed == 0 && decompressed.empty?
      end
    end
  end
end
