module Fastx
  class Error < Exception
  end

  class FastxError < Error
  end

  class InvalidCharacterError < FastxError
    def initialize(filename, name, sequence)
      msg = <<-ERROR
      Non-ASCII characters in FASTA file: #{filename}
        #{name}
        #{sequence}
      ERROR
      super(msg)
    end
  end

  class InvalidFormatError < FastxError
    def initialize(filename, idx, line, message = nil)
      msg = <<-ERROR
      Invalid Format: #{filename}:#{idx}
        #{line}
      #{message}
      ERROR
      super(msg)
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
