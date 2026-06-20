require "../exceptions"
require "../byte_lines"
require "compress/gzip"

module Fastx
  module Fastq
    class Reader
      @filename : Path?
      @file : File?
      @io : IO
      @consumed = false

      # Opens a FASTQ file, yields the reader to the block, and automatically closes it.
      def self.open(filename : String | Path, &)
        reader = new(filename)
        yield reader
      ensure
        reader.try &.close
      end

      # Opens a FASTQ stream, yields the reader to the block, and automatically closes it.
      def self.open(io : IO, &)
        reader = new(io)
        yield reader
      ensure
        reader.try &.close
      end

      # Creates a new FASTQ reader for the specified file.
      # Automatically detects gzip compression from .gz extension.
      def initialize(filename : String | Path)
        path = Path.new(filename)
        @filename = path
        file = File.open(filename)
        @file = file
        @io = path.extension == ".gz" ? Compress::Gzip::Reader.new(file) : file
      end

      # Creates a new FASTQ reader for an already opened IO stream.
      # IO-based readers do not perform gzip auto-detection.
      def initialize(io : IO)
        @filename = nil
        @file = nil
        @io = io
      end

      # Iterates over each FASTQ record, yielding identifier, sequence, and quality
      # as owned `String` copies that remain valid after iteration.
      def each(& : String, String, String ->)
        ensure_not_consumed!
        each_record do |identifier, sequence, quality|
          yield String.new(identifier), String.new(sequence), String.new(quality)
        end
      end

      # Iterates over each FASTQ record, yielding identifier, sequence, and quality
      # as borrowed `Bytes` (`Slice(UInt8)`).
      #
      # The yielded slices point into internal buffers that are reused on every
      # iteration: they are only valid until the next record is read. To keep a
      # value beyond the current iteration, copy it (`String.new(bytes)` or `bytes.dup`)
      # or use `#each`.
      def each_bytes(& : Bytes, Bytes, Bytes ->)
        ensure_not_consumed!
        each_record do |identifier, sequence, quality|
          yield identifier, sequence, quality
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
        identifier = IO::Memory.new
        sequence = IO::Memory.new
        quality = IO::Memory.new
        lines = ByteLines.new(@io)
        next_field = FIELD::IDENTIFIER
        line_number = 0
        quality_line_number = 0
        has_record = false

        while line = lines.next_line
          line_number += 1
          case next_field
          when FIELD::IDENTIFIER
            ensure_prefix!(line, 0x40u8, line_number, "Identifier line must start with '@'")

            if has_record
              yield_record(identifier, sequence, quality, quality_line_number) do |id, seq, qual|
                yield id, seq, qual
              end
            end
            identifier.clear
            identifier.write(line[1, line.size - 1])
            sequence.clear
            quality.clear
            has_record = true
            next_field = FIELD::SEQUENCE
          when FIELD::SEQUENCE
            append_ascii_line!(sequence, line, identifier)
            next_field = FIELD::PLUS
          when FIELD::PLUS
            ensure_prefix!(line, 0x2Bu8, line_number, "Plus line must start with '+'")
            next_field = FIELD::QUALITY
          when FIELD::QUALITY
            append_ascii_line!(quality, line, identifier)
            quality_line_number = line_number
            next_field = FIELD::IDENTIFIER
          end
        end

        raise_incomplete_record_error(next_field, line_number) unless next_field == FIELD::IDENTIFIER
        if has_record
          yield_record(identifier, sequence, quality, quality_line_number) do |id, seq, qual|
            yield id, seq, qual
          end
        end
      end

      private def ensure_prefix!(line : Bytes, prefix : UInt8, line_number : Int32, message : String)
        return if line.size > 0 && line[0] == prefix

        raise InvalidFormatError.new(source_label, line_number, String.new(line), message)
      end

      private def append_ascii_line!(buffer : IO::Memory, line : Bytes, identifier : IO::Memory)
        line.each do |byte|
          raise InvalidCharacterError.new(source_label, String.new(identifier.to_slice), String.new(line)) if byte > 0x7Fu8
        end

        buffer.write(line)
      end

      private def yield_record(identifier : IO::Memory, sequence : IO::Memory, quality : IO::Memory, line_number : Int32, &)
        validate_record!(sequence, quality, line_number)
        yield identifier.to_slice, sequence.to_slice, quality.to_slice
      end

      private def validate_record!(sequence : IO::Memory, quality : IO::Memory, line_number : Int32)
        return if sequence.bytesize == quality.bytesize

        raise InvalidFormatError.new(
          source_label,
          line_number,
          "",
          "sequence and quality lengths differ: sequence=#{sequence.bytesize}, quality=#{quality.bytesize}"
        )
      end

      private def raise_incomplete_record_error(next_field : FIELD, line_number : Int32)
        raise InvalidFormatError.new(source_label, line_number, "", "Incomplete FASTQ record: expected #{next_field}")
      end

      private def source_label
        @filename ? @filename.to_s : "<io>"
      end
    end
  end
end
