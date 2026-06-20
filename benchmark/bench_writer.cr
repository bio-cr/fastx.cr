# Writer throughput benchmark. Writes to /dev/null-like in-memory + real file.
#
#   crystal run --release benchmark/bench_writer.cr

require "../src/fastx"

N    = 500_000
SEQ  = String.build { |io| 150.times { io << "ACGT"[rand(4)] } }
QUAL = String.build { |io| 150.times { io << ('!'.ord + rand(40)).chr } }

def timed(label, &)
  GC.collect
  before = GC.stats.total_bytes
  start = Time.instant
  bytes = yield
  secs = (Time.instant - start).total_seconds
  alloc = (GC.stats.total_bytes - before).to_i64
  printf("%-32s  %7.3f s  %8.1f MB/s  alloc=%8.1f MB\n", label, secs, (bytes / 1e6) / secs, alloc / 1e6)
end

# FASTQ writer to a real file (buffered File IO)
timed("fastq writer -> file") do
  path = File.tempname("bench", ".fastq")
  Fastx::Fastq::Writer.open(path) do |writer|
    N.times { writer.write("read1 x", SEQ, QUAL) }
  end
  sz = File.size(path)
  File.delete(path)
  sz.to_i64
end

# FASTA writer no wrapping
timed("fasta writer (no wrap) -> file") do
  path = File.tempname("bench", ".fasta")
  Fastx::Fasta::Writer.open(path) do |writer|
    N.times { writer.write("seq1 x", SEQ) }
  end
  sz = File.size(path)
  File.delete(path)
  sz.to_i64
end

# FASTA writer wrapped at 70
timed("fasta writer (wrap 70) -> file") do
  path = File.tempname("bench", ".fasta")
  Fastx::Fasta::Writer.open(path, line_width: 70) do |writer|
    N.times { writer.write("seq1 x", SEQ) }
  end
  sz = File.size(path)
  File.delete(path)
  sz.to_i64
end
