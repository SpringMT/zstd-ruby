module Zstd
  class Context
    def initialize(*args)
      @args = args
      @cctx = nil
      @dctx = nil

      # Extract dictionary for DContext
      @dict = extract_dictionary_from_args(args)
    end

    def compress(data)
      @cctx ||= CContext.new(*@args)
      @cctx.compress(data)
    end

    def decompress(data)
      @dctx ||= create_dcontext
      @dctx.decompress(data)
    end

    private

    def extract_dictionary_from_args(args)
      return nil if args.empty?

      # Check if first argument is a hash with dict key
      if args.first.is_a?(Hash) && args.first.key?(:dict)
        return args.first[:dict]
      end

      # Check for positional dictionary argument (level, dict)
      if args.length == 2
        return args[1]
      end

      nil
    end

    def create_dcontext
      if @dict
        DContext.new(@dict)
      else
        DContext.new
      end
    end
  end
end
