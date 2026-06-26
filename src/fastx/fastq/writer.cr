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
      # IO-based writers do not perform gzip auto-detection. The writer takes
      # ownership of the IO and closes it when the writer is closed.
      def initialize(io : IO)
        @file = nil
        @io = io
      end

      # This write path is performance-sensitive. A union-typed method would be
      # shorter, but it was clearly slower than generated overloads in a tight
      # --release benchmark, so keep the overloads and route them to the Bytes core.
      {% for types in [
                        {String, String, String},
                        {String, String, Bytes},
                        {String, Bytes, String},
                        {String, Bytes, Bytes},
                        {Bytes, String, String},
                        {Bytes, String, Bytes},
                        {Bytes, Bytes, String},
                      ] %}
        # Writes a FASTQ record with the given identifier, sequence, and quality.
        def write(identifier : {{types[0]}}, sequence : {{types[1]}}, quality : {{types[2]}})
          write(bytes(identifier), bytes(sequence), bytes(quality))
        end
      {% end %}

      # Writes a FASTQ record with the given identifier, sequence, and quality.
      def write(identifier : Bytes, sequence : Bytes, quality : Bytes)
        unless sequence.size == quality.size
          raise ArgumentError.new("sequence and quality lengths differ")
        end

        @io.write_byte(0x40u8) # '@'
        @io.write(identifier)
        @io.write_byte(0x0Au8)
        @io.write(sequence)
        @io.write_byte(0x0Au8)
        @io.write_byte(0x2Bu8) # '+'
        @io.write_byte(0x0Au8)
        @io.write(quality)
        @io.write_byte(0x0Au8)
      end

      # Closes the writer and its underlying IO.
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
    end
  end
end
