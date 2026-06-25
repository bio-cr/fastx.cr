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

      # This write path is performance-sensitive. A union-typed method would be
      # shorter, but it was clearly slower than generated overloads in a tight
      # --release benchmark, so keep the overloads and route them to the Bytes core.
      {% for types in [{String, String}, {String, Bytes}, {Bytes, String}] %}
        # Writes a FASTA record with the given name and sequence.
        def write(name : {{types[0]}}, sequence : {{types[1]}})
          write(bytes(name), bytes(sequence))
        end
      {% end %}

      # Writes a FASTA record with the given name and sequence.
      def write(name : Bytes, sequence : Bytes)
        @io.write_byte(0x3Eu8) # '>'
        @io.write(name)
        @io.write_byte(0x0Au8)

        line_width = @line_width
        if line_width
          start = 0
          while start < sequence.size
            chunk_size = Math.min(line_width, sequence.size - start)
            @io.write(sequence[start, chunk_size])
            @io.write_byte(0x0Au8)
            start += chunk_size
          end
        else
          @io.write(sequence)
          @io.write_byte(0x0Au8)
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

      private def bytes(value : String) : Bytes
        value.to_slice
      end

      private def bytes(value : Bytes) : Bytes
        value
      end

      private def normalize_line_width(line_width : Int32?) : Int32?
        return if line_width.nil?
        raise ArgumentError.new("line_width must be positive") if line_width <= 0
        line_width
      end
    end
  end
end
