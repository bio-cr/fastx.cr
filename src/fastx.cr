require "./fastx/version"
require "./fastx/format"
require "./fastx/fasta"
require "./fastx/fastq"

module Fastx
  # Opens a FASTA/FASTQ file with automatic format detection or explicit format.
  # Yields the appropriate Reader/Writer to the block and automatically closes it.
  def self.open(filename : Path | String, mode = "r", format : Format? = nil, &) # block given
    return Fastq.open(filename, mode) { |reader_or_writer| yield reader_or_writer } if format == Format::FASTQ
    return Fasta.open(filename, mode) { |reader_or_writer| yield reader_or_writer } if format == Format::FASTA

    case filename.to_s
    when /\.fastq$/, /\.fq$/, /\.fastq.gz$/, /\.fq.gz$/
      Fastq.open(filename, mode) { |reader_or_writer| yield reader_or_writer }
    when /\.fasta$/, /\.fa$/, /\.fasta.gz$/, /\.fa.gz$/
      Fasta.open(filename, mode) { |reader_or_writer| yield reader_or_writer }
    else
      raise UnsupportedFormatError.new("Unknown format: #{filename}")
    end
  end

  # Opens a FASTA/FASTQ file with automatic format detection or explicit format.
  # Returns the appropriate Reader/Writer instance (manual close required).
  def self.open(filename : Path | String, mode = "r", format : Format? = nil)
    return Fastq.open(filename, mode) if format == Format::FASTQ
    return Fasta.open(filename, mode) if format == Format::FASTA

    case filename.to_s
    when /\.fastq$/, /\.fq$/, /\.fastq.gz$/, /\.fq.gz$/
      Fastq.open(filename, mode)
    when /\.fasta$/, /\.fa$/, /\.fasta.gz$/, /\.fa.gz$/
      Fasta.open(filename, mode)
    else
      raise UnsupportedFormatError.new("Unknown format: #{filename}")
    end
  end

  # Normalizes a single base character to uppercase.
  # When iupac is true, supports IUPAC nucleotide codes (R, Y, S, W, K, M, B, D, H, V).
  # When iupac is false, only standard bases (A, C, G, T, N) are preserved.
  # Non-recognized characters are converted to N (78u8).
  def self.normalize_base(c : UInt8, *, iupac : Bool = false, strict : Bool = false) : UInt8
    # Check standard bases first
    if standard_base = normalize_standard_base(c)
      return standard_base
    end

    # Check IUPAC codes if enabled
    if iupac
      if iupac_base = normalize_iupac_base(c)
        return iupac_base
      end
    end

    # Convert unknown characters to N
    replace_with_n(c, strict: strict)
  end

  # Private method to normalize standard bases (A, C, G, T, N)
  private def self.normalize_standard_base(c : UInt8) : UInt8?
    case c
    when 65u8, 97u8  then 65u8 # A
    when 67u8, 99u8  then 67u8 # C
    when 71u8, 103u8 then 71u8 # G
    when 84u8, 116u8 then 84u8 # T
    when 78u8, 110u8 then 78u8 # N
    end
  end

  # Private method to normalize IUPAC ambiguous bases
  private def self.normalize_iupac_base(c : UInt8) : UInt8?
    case c
    when 82u8, 114u8 then 82u8 # R (A or G)
    when 89u8, 121u8 then 89u8 # Y (C or T)
    when 83u8, 115u8 then 83u8 # S (G or C)
    when 87u8, 119u8 then 87u8 # W (A or T)
    when 75u8, 107u8 then 75u8 # K (G or T)
    when 77u8, 109u8 then 77u8 # M (A or C)
    when 66u8, 98u8  then 66u8 # B (C or G or T)
    when 68u8, 100u8 then 68u8 # D (A or G or T)
    when 72u8, 104u8 then 72u8 # H (A or C or T)
    when 86u8, 118u8 then 86u8 # V (A or C or G)
    end
  end

  # Private method to replace unknown characters with N and log the replacement
  private def self.replace_with_n(c : UInt8, *, strict : Bool) : UInt8
    raise InvalidBaseError.new(c) if strict
    78u8 # N
  end

  # Converts a DNA sequence (`Bytes` or `String`) to a UInt8 slice,
  # where each base is encoded as a single byte.
  # When iupac is true, supports IUPAC nucleotide codes (R, Y, S, W, K, M, B, D, H, V).
  # When iupac is false, only standard bases (A, C, G, T, N) are preserved.
  # Non-recognized characters are converted to N (78u8).
  # This representation is suitable for byte-wise or array processing.
  def self.encode_bases(sequence : Bytes, *, iupac : Bool = false, strict : Bool = false) : Slice(UInt8)
    sequence.map do |byte|
      normalize_base(byte, iupac: iupac, strict: strict)
    end
  end

  # :ditto:
  def self.encode_bases(sequence : String, *, iupac : Bool = false, strict : Bool = false) : Slice(UInt8)
    encode_bases(sequence.to_slice, iupac: iupac, strict: strict)
  end

  # Converts a UInt8 array (ASCII codes) to a DNA string.
  def self.decode_bases(bases : Bytes) : String
    String.new(bases)
  end

  # Converts a UInt8 array (ASCII codes) to a DNA string.
  def self.decode_bases(bases : Array(UInt8)) : String
    String.new(Slice.new(bases.to_unsafe, bases.size))
  end

  # Converts a UInt8 array (ASCII codes) to a DNA string.
  def self.decode_bases(bases : Enumerable(UInt8)) : String
    bytes = bases.to_a
    String.new(Slice.new(bytes.to_unsafe, bytes.size))
  end
end
