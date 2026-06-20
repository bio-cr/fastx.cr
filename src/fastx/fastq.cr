require "./fastq/reader"
require "./fastq/writer"

module Fastx
  module Fastq
    # FASTQ record field types for parsing state machine.
    enum FIELD : UInt8
      IDENTIFIER = 0
      SEQUENCE   = 1
      PLUS       = 2
      QUALITY    = 3
    end

    # Opens a FASTQ file for reading ("r") or writing ("w").
    # Yields the Reader/Writer to the block and automatically closes it.
    def self.open(filename, mode = "r", &) # block given
      case mode
      when "r"
        Reader.open(filename) { |reader| yield reader }
      when "w"
        Writer.open(filename) { |writer| yield writer }
      else
        raise ArgumentError.new("Invalid mode: #{mode}")
      end
    end

    # Opens a FASTQ file for reading ("r") or writing ("w").
    # Returns the Reader/Writer instance (manual close required).
    def self.open(filename, mode = "r")
      case mode
      when "r"
        Reader.new(filename)
      when "w"
        Writer.new(filename)
      else
        raise ArgumentError.new("Invalid mode: #{mode}")
      end
    end
  end

  # Converts a quality sequence (`Bytes`) to an array of Phred scores.
  def self.encode_phred(quality : Bytes, offset = 33) : Array(UInt8)
    scores = Array(UInt8).new(quality.size)
    quality.each do |byte|
      scores << (byte - offset).to_u8
    end
    scores
  end

  # Converts a quality string to an array of Phred scores.
  def self.encode_phred(quality : String, offset = 33) : Array(UInt8)
    encode_phred(quality.to_slice, offset)
  end

  # Converts an array of Phred scores to a quality string.
  def self.decode_phred(scores : Bytes, offset = 33) : String
    String.new(scores.size) do |buffer|
      index = 0
      while index < scores.size
        buffer[index] = (scores[index] + offset).to_u8
        index += 1
      end
      {scores.size, scores.size}
    end
  end

  # Converts an array of Phred scores to a quality string.
  def self.decode_phred(scores : Array(UInt8), offset = 33) : String
    String.new(scores.size) do |buffer|
      index = 0
      while index < scores.size
        buffer[index] = (scores.unsafe_fetch(index) + offset).to_u8
        index += 1
      end
      {scores.size, scores.size}
    end
  end

  # Converts an array of Phred scores to a quality string.
  def self.decode_phred(scores : Enumerable(UInt8), offset = 33) : String
    String.build do |io|
      scores.each do |score|
        io << (score + offset).chr
      end
    end
  end
end
