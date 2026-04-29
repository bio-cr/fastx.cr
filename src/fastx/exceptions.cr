module Fastx
  class Error < Exception
  end

  class FastxError < Error
  end

  class InvalidCharacterError < FastxError
    def initialize(filename, name, sequence)
      super("Non-ASCII characters in FASTA file: #{filename}\n  #{name}\n  #{sequence}")
    end
  end

  class InvalidFormatError < FastxError
    def initialize(filename, idx, line, message = nil)
      super("Invalid Format: #{filename}:#{idx}\n  #{line}\n#{message}")
    end
  end

  class InvalidBaseError < FastxError
    def initialize(base : UInt8)
      super("Invalid base: #{base.chr.inspect}")
    end
  end

  class ReaderConsumedError < FastxError
    def initialize(message = "Reader is one-pass only and has already been consumed")
      super(message)
    end
  end

  class UnsupportedFormatError < FastxError
  end
end
