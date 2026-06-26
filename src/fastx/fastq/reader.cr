require "../exceptions"
require "../byte_lines"
require "compress/gzip"

module Fastx
  module Fastq
    # Coordinates streaming of a conventional four-line FASTQ record over a
    # shared `ByteLines` scanner.
    private class RecordCursor
      getter line_number : Int32
      getter sequence_length : Int32 = 0
      getter quality_length : Int32 = 0

      def initialize(@lines : ByteLines, @id : String, @source_label : String, @line_number : Int32)
        @sequence_read = false
        @plus_read = false
        @quality_read = false
      end

      # Returns the sequence line once, then `nil`.
      def next_sequence_line : Bytes?
        return if @sequence_read
        @sequence_read = true

        line = @lines.next_line
        raise_incomplete("sequence") if line.nil?
        @line_number += 1

        validate_ascii!(line)
        @sequence_length += line.size
        line
      end

      # Returns the quality line once, then `nil`. Auto-drains the sequence line
      # first so the sequence length is known even if the caller skipped it.
      def next_quality_line : Bytes?
        drain_sequence unless @sequence_read
        return if @quality_read
        read_plus_line unless @plus_read
        @quality_read = true

        line = @lines.next_line
        raise_incomplete("quality") if line.nil?
        @line_number += 1

        validate_ascii!(line)
        @quality_length += line.size
        validate_lengths!
        line
      end

      def drain_sequence : Nil
        next_sequence_line
      end

      # Consumes any unread sequence and quality lines, leaving the scanner
      # positioned at the next record. Also surfaces length-mismatch errors when
      # the caller did not read the streams to completion.
      def drain : Nil
        drain_sequence unless @sequence_read
        next_quality_line unless @quality_read
      end

      private def validate_ascii!(line : Bytes) : Nil
        line.each do |byte|
          raise InvalidCharacterError.new(@source_label, @id, String.new(line)) if byte > 0x7Fu8
        end
      end

      private def raise_incomplete(expected : String) : NoReturn
        raise InvalidFormatError.new(
          @source_label, @line_number, "", "Incomplete FASTQ record: expected #{expected}"
        )
      end

      private def read_plus_line : Nil
        line = @lines.next_line
        raise_incomplete("'+' separator") if line.nil?
        @line_number += 1
        @plus_read = true

        return if line.size > 0 && line[0] == 0x2Bu8

        raise InvalidFormatError.new(@source_label, @line_number, String.new(line), "Plus line must start with '+'")
      end

      private def validate_lengths! : Nil
        return if @sequence_length == @quality_length

        raise InvalidFormatError.new(
          @source_label,
          @line_number,
          "",
          "sequence and quality lengths differ: sequence=#{@sequence_length}, quality=#{@quality_length}"
        )
      end
    end

    # Streams the sequence lines of a single FASTQ record as borrowed `Bytes`.
    #
    # Each yielded slice points into a buffer reused on every line and is only
    # valid until the next line is read. Copy it (`String.new(bytes)` or
    # `bytes.dup`) to keep it.
    class SequenceLines
      def initialize(@cursor : RecordCursor)
      end

      def each(& : Bytes ->) : Nil
        while line = @cursor.next_sequence_line
          yield line
        end
      end

      def drain : Nil
        @cursor.drain_sequence
      end
    end

    # Streams the quality lines of a single FASTQ record as borrowed `Bytes`.
    #
    # The sequence line is consumed first (automatically, if the caller skips
    # it) so the quality length can be validated. Each yielded slice is only
    # valid until the next line is read; copy it to keep it.
    class QualityLines
      def initialize(@cursor : RecordCursor)
      end

      def each(& : Bytes ->) : Nil
        while line = @cursor.next_quality_line
          yield line
        end
      end

      def drain : Nil
        @cursor.next_quality_line
      end
    end

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
        each_buffered_record do |identifier, sequence, quality|
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
        each_buffered_record do |identifier, sequence, quality|
          yield identifier, sequence, quality
        end
      end

      # Iterates over conventional four-line FASTQ records while streaming each
      # record's sequence and quality lines without accumulating the full fields
      # in memory.
      #
      # The yielded identifier is an owned `String`. `SequenceLines#each` and
      # `QualityLines#each` yield borrowed `Bytes` slices into an internal buffer;
      # each slice is only valid until the next line is read. Copy it
      # (`String.new(bytes)` or `bytes.dup`) to keep it.
      #
      # The sequence line is consumed before quality (automatically, if the
      # caller skips it) so sequence/quality length equality can be validated.
      #
      # The specific method name leaves `#each_record` available for a possible
      # future record-oriented API.
      def each_record_lines(& : String, SequenceLines, QualityLines ->)
        ensure_not_consumed!

        lines = ByteLines.new(@io)
        line_number = 0

        loop do
          line = lines.next_line
          return if line.nil?
          line_number += 1
          ensure_prefix!(line, 0x40u8, line_number, "Identifier line must start with '@'")

          id = String.new(line[1, line.size - 1])
          cursor = RecordCursor.new(lines, id, source_label, line_number)
          yield id, SequenceLines.new(cursor), QualityLines.new(cursor)
          cursor.drain
          line_number = cursor.line_number
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

      private def each_buffered_record(&)
        identifier = IO::Memory.new
        sequence = IO::Memory.new
        quality = IO::Memory.new
        lines = ByteLines.new(@io)
        line_number = 0

        while identifier_line = lines.next_line
          line_number += 1
          ensure_prefix!(identifier_line, 0x40u8, line_number, "Identifier line must start with '@'")

          identifier.clear
          identifier.write(identifier_line[1, identifier_line.size - 1])
          sequence.clear
          quality.clear

          sequence_line = lines.next_line
          raise_incomplete_record_error("sequence", line_number) if sequence_line.nil?
          line_number += 1
          append_ascii_line!(sequence, sequence_line, identifier)

          plus_line = lines.next_line
          raise_incomplete_record_error("'+' separator", line_number) if plus_line.nil?
          line_number += 1
          ensure_prefix!(plus_line, 0x2Bu8, line_number, "Plus line must start with '+'")

          quality_line = lines.next_line
          raise_incomplete_record_error("quality", line_number) if quality_line.nil?
          line_number += 1
          append_ascii_line!(quality, quality_line, identifier)

          yield_record(identifier, sequence, quality, line_number) do |id, seq, qual|
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

      private def raise_incomplete_record_error(expected : String, line_number : Int32)
        raise InvalidFormatError.new(source_label, line_number, "", "Incomplete FASTQ record: expected #{expected}")
      end

      private def source_label
        @filename ? @filename.to_s : "<io>"
      end
    end
  end
end
