require "../exceptions"
require "compress/gzip"

module Fastx
  module Fasta
    class Reader
      @filename : Path?
      @file : File?
      @io : IO
      @consumed = false

      # Opens a FASTA file, yields the reader to the block, and automatically closes it.
      def self.open(filename : String | Path, &)
        reader = new(filename)
        yield reader
      ensure
        reader.try &.close
      end

      # Opens a FASTA stream, yields the reader to the block, and automatically closes it.
      def self.open(io : IO, &)
        reader = new(io)
        yield reader
      ensure
        reader.try &.close
      end

      # Creates a new FASTA reader for the specified file.
      # Automatically detects gzip compression from .gz extension.
      def initialize(filename : String | Path)
        path = Path.new(filename)
        @filename = path
        file = File.open(filename)
        @file = file
        @io = path.extension == ".gz" ? Compress::Gzip::Reader.new(file) : file
      end

      # Creates a new FASTA reader for an already opened IO stream.
      # IO-based readers do not perform gzip auto-detection.
      def initialize(io : IO)
        @filename = nil
        @file = nil
        @io = io
      end

      # Iterates over each FASTA record, yielding name and sequence.
      # This method reuses its internal sequence buffer until the next iteration.
      def each(&)
        ensure_not_consumed!
        each_record do |name, sequence|
          yield name, sequence
        end
      end

      # Iterates over each FASTA record, yielding name and sequence as String copies.
      def each_copy(&)
        ensure_not_consumed!
        each_record do |name, sequence|
          yield name, sequence.to_s
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

      private def ensure_not_consumed!
        raise ReaderConsumedError.new if @consumed
        @consumed = true
      end

      private def each_record(&)
        name = nil
        sequence = IO::Memory.new

        @io.each_line do |line|
          if line.starts_with?(">")
            yield name, sequence unless name.nil?
            name = line[1..-1]
            sequence.clear
          else
            raise InvalidCharacterError.new(source_label, name, line) unless line.ascii_only?
            sequence << line
          end
        end

        yield name, sequence unless name.nil?
      end

      private def source_label
        @filename ? @filename.to_s : "<io>"
      end
    end
  end
end
