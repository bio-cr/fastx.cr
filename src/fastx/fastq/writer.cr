require "../exceptions"
require "compress/gzip"

module Fastx
  module Fastq
    class Writer
      @file : File?
      @io : IO

      # Opens a FASTQ file for writing, yields the writer to the block, and automatically closes it.
      def self.open(filename : String | Path, &)
        writer = new(filename)
        yield writer
      ensure
        writer.try &.close
      end

      # Opens a FASTQ stream for writing, yields the writer to the block, and automatically closes it.
      def self.open(io : IO, &)
        writer = new(io)
        yield writer
      ensure
        writer.try &.close
      end

      # Creates a new FASTQ writer for the specified file.
      # Automatically detects gzip compression from .gz extension.
      def initialize(filename : String | Path)
        filename = Path.new(filename)
        file = File.open(filename, "w")
        @file = file
        @io = filename.extension == ".gz" ? Compress::Gzip::Writer.new(file) : file
      end

      # Creates a new FASTQ writer for an already opened IO stream.
      # IO-based writers do not perform gzip auto-detection.
      def initialize(io : IO)
        @file = nil
        @io = io
      end

      # Writes a FASTQ record with the given identifier, sequence, and quality.
      def write(identifier : String, sequence : String, quality : String)
        unless sequence.bytesize == quality.bytesize
          raise ArgumentError.new("sequence and quality lengths differ")
        end

        @io << '@' << identifier << '\n'
        @io << sequence << '\n'
        @io << "+\n"
        @io << quality << '\n'
      end

      # Closes the file handle.
      def close
        @io.close unless @io.closed?

        file = @file
        file.close if file && !file.closed?
      end

      # Returns true if the file handle is closed.
      def closed?
        @io.closed?
      end
    end
  end
end
