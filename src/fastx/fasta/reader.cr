require "../exceptions"
require "../byte_lines"
require "compress/gzip"

module Fastx
  module Fasta
    class SequenceLines
      def initialize(
        @lines : ByteLines,
        @name : String,
        @source_label : String,
        @set_pending_name : Proc(String, Nil),
      )
        @done = false
      end

      def each(& : Bytes ->)
        return if @done

        while line = @lines.next_line
          if fasta_header?(line)
            @set_pending_name.call(String.new(line[1, line.size - 1]))
            @done = true
            return
          end

          validate_ascii_line!(line)
          yield line
        end

        @done = true
      end

      def drain
        each { |_| }
      end

      private def fasta_header?(line : Bytes) : Bool
        line.size > 0 && line[0] == 0x3Eu8
      end

      private def validate_ascii_line!(line : Bytes)
        line.each do |byte|
          raise InvalidCharacterError.new(@source_label, @name, String.new(line)) if byte > 0x7Fu8
        end
      end
    end

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

      # Iterates over FASTA records while streaming sequence lines without
      # accumulating the full sequence in memory.
      #
      # The yielded name is an owned `String`. `SequenceLines#each` yields
      # borrowed `Bytes` slices into an internal buffer; each slice is only valid
      # until the next line is read. Copy it (`String.new(bytes)` or `bytes.dup`)
      # to keep it.
      def each_record_lines(& : String, SequenceLines ->)
        ensure_not_consumed!

        lines = ByteLines.new(@io)
        pending_name = nil

        loop do
          name = pending_name
          pending_name = nil

          unless name
            line = lines.next_line
            return unless line
            ensure_header!(line)
            name = String.new(line[1, line.size - 1])
          end

          sequence_lines = SequenceLines.new(lines, name, source_label, ->(next_name : String) { pending_name = next_name })
          yield name, sequence_lines
          sequence_lines.drain
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
        line = lines.next_line
        return unless line
        ensure_header!(line)

        name.write(line[1, line.size - 1])

        while line = lines.next_line
          if fasta_header?(line)
            yield name.to_slice, sequence.to_slice
            name.clear
            name.write(line[1, line.size - 1])
            sequence.clear
          else
            append_ascii_line!(sequence, line, name)
          end
        end

        yield name.to_slice, sequence.to_slice
      end

      private def append_ascii_line!(sequence : IO::Memory, line : Bytes, name : IO::Memory)
        line.each do |byte|
          raise InvalidCharacterError.new(source_label, String.new(name.to_slice), String.new(line)) if byte > 0x7Fu8
        end

        sequence.write(line)
      end

      private def validate_ascii_line!(line : Bytes, name : String)
        line.each do |byte|
          raise InvalidCharacterError.new(source_label, name, String.new(line)) if byte > 0x7Fu8
        end
      end

      private def ensure_header!(line : Bytes) : Nil
        return if fasta_header?(line)

        raise InvalidFormatError.new(source_label, 1, String.new(line), "Header line must start with '>'")
      end

      private def fasta_header?(line : Bytes) : Bool
        line.size > 0 && line[0] == 0x3Eu8
      end

      private def source_label
        @filename ? @filename.to_s : "<io>"
      end
    end
  end
end
