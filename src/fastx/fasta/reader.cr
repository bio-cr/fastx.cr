require "../exceptions"
require "../byte_lines"
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

      # Iterates over each FASTA record, yielding name and sequence as owned
      # `String` copies that remain valid after iteration.
      def each(& : String, String ->)
        ensure_not_consumed!
        each_record do |name, sequence|
          yield String.new(name), String.new(sequence)
        end
      end

      # Iterates over each FASTA record, yielding name and sequence as borrowed
      # `Bytes` (`Slice(UInt8)`).
      #
      # The yielded slices point into internal buffers that are reused on every
      # iteration: they are only valid until the next record is read. To keep a
      # value beyond the current iteration, copy it (`String.new(bytes)` or `bytes.dup`)
      # or use `#each`.
      def each_bytes(& : Bytes, Bytes ->)
        ensure_not_consumed!
        each_record do |name, sequence|
          yield name, sequence
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
        name = IO::Memory.new
        sequence = IO::Memory.new
        lines = ByteLines.new(@io)
        has_record = false

        while line = lines.next_line
          if line.size > 0 && line[0] == 0x3Eu8
            yield name.to_slice, sequence.to_slice if has_record
            name.clear
            name.write(line[1, line.size - 1])
            sequence.clear
            has_record = true
          else
            append_ascii_line!(sequence, line, name)
          end
        end

        yield name.to_slice, sequence.to_slice if has_record
      end

      private def append_ascii_line!(sequence : IO::Memory, line : Bytes, name : IO::Memory)
        line.each do |byte|
          raise InvalidCharacterError.new(source_label, String.new(name.to_slice), String.new(line)) if byte > 0x7Fu8
        end

        sequence.write(line)
      end

      private def source_label
        @filename ? @filename.to_s : "<io>"
      end
    end
  end
end
