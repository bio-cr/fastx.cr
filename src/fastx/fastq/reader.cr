require "../exceptions"
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

      # Iterates over each FASTQ record, yielding identifier, sequence, and quality.
      # This method reuses internal buffers, so sequence and quality are only valid until the next iteration.
      def each(&)
        ensure_not_consumed!
        each_record do |identifier, sequence, quality|
          yield identifier, sequence, quality
        end
      end

      # Iterates over each FASTQ record, yielding identifier, sequence, and quality as String copies.
      def each_copy(&)
        ensure_not_consumed!
        each_record do |identifier, sequence, quality|
          yield identifier, sequence.to_s, quality.to_s
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
        identifier = nil
        sequence = IO::Memory.new
        quality = IO::Memory.new
        next_field = FIELD::IDENTIFIER
        quality_line_number = 0

        @io.each_line.with_index(1) do |line, line_number|
          case next_field
          when FIELD::IDENTIFIER
            unless line.starts_with?("@")
              raise InvalidFormatError.new(source_label, line_number, line, "Identifier line must start with '@'")
            end

            yield_record(identifier, sequence, quality, quality_line_number) do |id, seq, qual|
              yield id, seq, qual
            end unless identifier.nil?
            identifier = line[1..-1]
            sequence.clear
            quality.clear
            next_field = FIELD::SEQUENCE
          when FIELD::SEQUENCE
            unless line.ascii_only?
              raise InvalidCharacterError.new(source_label, identifier, line)
            end
            sequence << line
            next_field = FIELD::PLUS
          when FIELD::PLUS
            unless line.starts_with?("+")
              raise InvalidFormatError.new(source_label, line_number, line, "Plus line must start with '+'")
            end
            next_field = FIELD::QUALITY
          when FIELD::QUALITY
            unless line.ascii_only?
              raise InvalidCharacterError.new(source_label, identifier, line)
            end
            quality << line
            quality_line_number = line_number
            next_field = FIELD::IDENTIFIER
          end
        end

        raise_incomplete_record_error(next_field, quality_line_number) unless next_field == FIELD::IDENTIFIER
        yield_record(identifier, sequence, quality, quality_line_number) do |id, seq, qual|
          yield id, seq, qual
        end unless identifier.nil?
      end

      private def yield_record(identifier : String, sequence : IO::Memory, quality : IO::Memory, line_number : Int32, &)
        validate_record!(sequence, quality, line_number)
        yield identifier, sequence, quality
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
