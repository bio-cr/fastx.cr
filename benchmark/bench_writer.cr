# Writer throughput benchmark. Writes to a null IO plus real files.
#
#   crystal run --release benchmark/bench_writer.cr

require "../src/fastx"

N    = 500_000
ID   = "read1 x"
SEQ  = String.build { |io| 150.times { io << "ACGT"[rand(4)] } }
QUAL = String.build { |io| 150.times { io << ('!'.ord + rand(40)).chr } }

ID_BYTES   = ID.to_slice
SEQ_BYTES  = SEQ.to_slice
QUAL_BYTES = QUAL.to_slice

FASTQ_RECORD_BYTES = 1 + ID.bytesize + 1 + SEQ.bytesize + 1 + 2 + QUAL.bytesize + 1
FASTA_RECORD_BYTES = 1 + ID.bytesize + 1 + SEQ.bytesize + 1

class NullIO < IO
  def read(slice : Bytes) : Int32
    0
  end

  def write(slice : Bytes) : Nil
  end
end

def timed(label, &)
  GC.collect
  before = GC.stats.total_bytes
  start = Time.instant
  bytes = yield
  secs = (Time.instant - start).total_seconds
  alloc = (GC.stats.total_bytes - before).to_i64
  printf("%-32s  %7.3f s  %8.1f MB/s  alloc=%8.1f MB\n", label, secs, (bytes / 1e6) / secs, alloc / 1e6)
end

def make_fastq_input : String
  path = File.tempname("bench", ".fastq")
  Fastx::Fastq::Writer.open(path) do |writer|
    N.times { writer.write(ID_BYTES, SEQ_BYTES, QUAL_BYTES) }
  end
  path
end

# FASTQ writer to a null IO, which highlights writer overhead and allocation.
timed("fastq string -> null") do
  Fastx::Fastq::Writer.open(NullIO.new) do |writer|
    N.times { writer.write(ID, SEQ, QUAL) }
  end
  (FASTQ_RECORD_BYTES * N).to_i64
end

timed("fastq bytes -> null") do
  Fastx::Fastq::Writer.open(NullIO.new) do |writer|
    N.times { writer.write(ID_BYTES, SEQ_BYTES, QUAL_BYTES) }
  end
  (FASTQ_RECORD_BYTES * N).to_i64
end

timed("fastq mixed -> null") do
  Fastx::Fastq::Writer.open(NullIO.new) do |writer|
    N.times { writer.write(ID, SEQ_BYTES, QUAL_BYTES) }
  end
  (FASTQ_RECORD_BYTES * N).to_i64
end

# FASTQ writer to a real file (buffered File IO).
timed("fastq bytes -> file") do
  path = File.tempname("bench", ".fastq")
  Fastx::Fastq::Writer.open(path) do |writer|
    N.times { writer.write(ID_BYTES, SEQ_BYTES, QUAL_BYTES) }
  end
  size = File.size(path)
  File.delete(path)
  size.to_i64
end

# FASTA writer no wrapping.
timed("fasta string -> null") do
  Fastx::Fasta::Writer.open(NullIO.new) do |writer|
    N.times { writer.write(ID, SEQ) }
  end
  (FASTA_RECORD_BYTES * N).to_i64
end

timed("fasta bytes -> null") do
  Fastx::Fasta::Writer.open(NullIO.new) do |writer|
    N.times { writer.write(ID_BYTES, SEQ_BYTES) }
  end
  (FASTA_RECORD_BYTES * N).to_i64
end

timed("fasta mixed -> null") do
  Fastx::Fasta::Writer.open(NullIO.new) do |writer|
    N.times { writer.write(ID, SEQ_BYTES) }
  end
  (FASTA_RECORD_BYTES * N).to_i64
end

timed("fasta bytes -> file") do
  path = File.tempname("bench", ".fasta")
  Fastx::Fasta::Writer.open(path) do |writer|
    N.times { writer.write(ID_BYTES, SEQ_BYTES) }
  end
  size = File.size(path)
  File.delete(path)
  size.to_i64
end

# FASTA writer wrapped at 70.
timed("fasta bytes wrap70 -> file") do
  path = File.tempname("bench", ".fasta")
  Fastx::Fasta::Writer.open(path, line_width: 70) do |writer|
    N.times { writer.write(ID_BYTES, SEQ_BYTES) }
  end
  size = File.size(path)
  File.delete(path)
  size.to_i64
end

# End-to-end path enabled by borrowed reader slices.
fastq_input = make_fastq_input
begin
  timed("fastq each_bytes -> null") do
    Fastx::Fastq::Reader.open(fastq_input) do |reader|
      Fastx::Fastq::Writer.open(NullIO.new) do |writer|
        reader.each_bytes { |id, seq, qual| writer.write(id, seq, qual) }
      end
    end
    File.size(fastq_input).to_i64
  end
ensure
  File.delete(fastq_input) if File.exists?(fastq_input)
end
