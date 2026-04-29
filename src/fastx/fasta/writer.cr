require "../exceptions"
require "compress/gzip"

module Fastx
  module Fasta
    class Writer
      @file : File?
      @io : IO
      @line_width : Int32?

      # Opens a FASTA file for writing, yields the writer to the block, and automatically closes it.
      def self.open(filename : String | Path, line_width : Int32? = nil, &)
        writer = new(filename, line_width: line_width)
        yield writer
      ensure
        writer.try &.close
      end

      # Opens a FASTA stream for writing, yields the writer to the block, and automatically closes it.
      def self.open(io : IO, line_width : Int32? = nil, &)
        writer = new(io, line_width: line_width)
        yield writer
      ensure
        writer.try &.close
      end

      # Creates a new FASTA writer for the specified file.
      # Automatically detects gzip compression from .gz extension.
      def initialize(filename : String | Path, line_width : Int32? = nil)
        filename = Path.new(filename)
        file = File.open(filename, "w")
        @file = file
        @io = filename.extension == ".gz" ? Compress::Gzip::Writer.new(file) : file
        @line_width = normalize_line_width(line_width)
      end

      # Creates a new FASTA writer for an already opened IO stream.
      # IO-based writers do not perform gzip auto-detection.
      def initialize(io : IO, line_width : Int32? = nil)
        @file = nil
        @io = io
        @line_width = normalize_line_width(line_width)
      end

      # Writes a FASTA record with the given name and sequence.
      def write(name : String, sequence : String)
        @io << '>' << name << '\n'

        line_width = @line_width
        if line_width
          bytes = sequence.to_slice
          start = 0
          while start < bytes.size
            chunk_size = Math.min(line_width, bytes.size - start)
            @io.write(bytes[start, chunk_size])
            @io << '\n'
            start += chunk_size
          end
        else
          @io << sequence << '\n'
        end
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

      private def normalize_line_width(line_width : Int32?) : Int32?
        return if line_width.nil?
        raise ArgumentError.new("line_width must be positive") if line_width <= 0
        line_width
      end
    end
  end
end
