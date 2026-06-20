# Synthetic FASTA/FASTQ data generator for benchmarking.
#
# Usage:
#   crystal run --release benchmark/gen_data.cr -- <outdir>
#
# Produces deterministic (seeded) datasets of varying shapes so benchmarks
# are reproducible across runs.

require "compress/gzip"

OUT = ARGV[0]? || "benchmark/data"
Dir.mkdir_p(OUT)

# Simple deterministic LCG so we don't depend on Random's implementation.
class LCG
  def initialize(@state : UInt64 = 0x2545F4914F6CDD1Du64)
  end

  def next_byte : UInt8
    @state = @state &* 6364136223846793005u64 &+ 1442695040888963407u64
    ((@state >> 33) & 0xFF).to_u8
  end

  def base : UInt8
    case next_byte & 0x3
    when 0 then 'A'.ord.to_u8
    when 1 then 'C'.ord.to_u8
    when 2 then 'G'.ord.to_u8
    else        'T'.ord.to_u8
    end
  end

  def qual : UInt8
    # Phred 33 range, '!'(33) .. 'I'(73)
    (33u8 + (next_byte % 41u8))
  end
end

def write_seq(io : IO, rng : LCG, len : Int32, line_width : Int32?)
  if line_width
    written = 0
    while written < len
      chunk = Math.min(line_width, len - written)
      chunk.times { io << rng.base.chr }
      io << '\n'
      written += chunk
    end
  else
    len.times { io << rng.base.chr }
    io << '\n'
  end
end

def gen_fasta(path : String, n : Int32, seq_len : Int32, line_width : Int32?)
  rng = LCG.new
  File.open(path, "w") do |file|
    n.times do |i|
      file << ">seq" << i << " synthetic record\n"
      write_seq(file, rng, seq_len, line_width)
    end
  end
  puts "wrote #{path} (#{File.size(path)} bytes)"
end

def gen_fastq(path : String, n : Int32, seq_len : Int32)
  rng = LCG.new
  File.open(path, "w") do |file|
    n.times do |i|
      file << "@read" << i << " synthetic\n"
      seq_len.times { file << rng.base.chr }
      file << "\n+\n"
      seq_len.times { file << rng.qual.chr }
      file << '\n'
    end
  end
  puts "wrote #{path} (#{File.size(path)} bytes)"
end

def gzip_file(path : String)
  dest = "#{path}.gz"
  File.open(path) do |src|
    File.open(dest, "w") do |dst|
      Compress::Gzip::Writer.open(dst) do |gzip|
        IO.copy(src, gzip)
      end
    end
  end
  puts "wrote #{dest} (#{File.size(dest)} bytes)"
end

# FASTA: many short records (single-line seq)
gen_fasta("#{OUT}/reads_short.fasta", 200_000, 150, nil)
# FASTA: few long records, wrapped at 70 cols (genome-like, multi-line)
gen_fasta("#{OUT}/genome_wrapped.fasta", 50, 2_000_000, 70)
# FASTA: few long records, single line
gen_fasta("#{OUT}/genome_oneline.fasta", 50, 2_000_000, nil)

# FASTQ: many short reads (Illumina-like)
gen_fastq("#{OUT}/reads.fastq", 500_000, 150)

# gzip variants of the read-heavy files
gzip_file("#{OUT}/reads_short.fasta")
gzip_file("#{OUT}/reads.fastq")

puts "done"
