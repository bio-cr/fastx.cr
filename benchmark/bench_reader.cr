# Reader throughput + allocation benchmark for the CURRENT implementation.
#
#   crystal run --release benchmark/bench_reader.cr -- benchmark/data
#
# Reports wall time, MB/s (input bytes), and bytes allocated (GC) per pass.

require "../src/fastx"

DATA = ARGV[0]? || "benchmark/data"

def measure(label : String, path : String, &block : -> Int64)
  return unless File.exists?(path)
  file_size = File.size(path)

  # warm up once (also pages in the file cache)
  block.call

  GC.collect
  before_alloc = GC.stats.total_bytes
  start = Time.instant
  total = block.call
  elapsed = Time.instant - start
  after_alloc = GC.stats.total_bytes

  allocated = (after_alloc - before_alloc).to_i64
  secs = elapsed.total_seconds
  mbps = (file_size / 1e6) / secs
  alloc_ratio = allocated.to_f / file_size

  printf("%-28s  %7.3f s  %8.1f MB/s  alloc=%9.1f MB  (%.2fx input)  units=%d\n",
    label, secs, mbps, allocated / 1e6, alloc_ratio, total)
end

# --- FASTA, borrowed (each) : counts total sequence bytes ---
measure("fasta short (each)", "#{DATA}/reads_short.fasta") do
  bytes = 0i64
  Fastx::Fasta::Reader.open("#{DATA}/reads_short.fasta") do |reader|
    reader.each { |_name, seq| bytes += seq.size }
  end
  bytes
end

measure("fasta short (each_bytes)", "#{DATA}/reads_short.fasta") do
  bytes = 0i64
  Fastx::Fasta::Reader.open("#{DATA}/reads_short.fasta") do |reader|
    reader.each_bytes { |_name, seq| bytes += seq.size }
  end
  bytes
end

measure("fasta short.gz (each)", "#{DATA}/reads_short.fasta.gz") do
  bytes = 0i64
  Fastx::Fasta::Reader.open("#{DATA}/reads_short.fasta.gz") do |reader|
    reader.each { |_name, seq| bytes += seq.size }
  end
  bytes
end

measure("fasta genome wrapped (each)", "#{DATA}/genome_wrapped.fasta") do
  bytes = 0i64
  Fastx::Fasta::Reader.open("#{DATA}/genome_wrapped.fasta") do |reader|
    reader.each { |_name, seq| bytes += seq.size }
  end
  bytes
end

measure("fasta genome oneline (each)", "#{DATA}/genome_oneline.fasta") do
  bytes = 0i64
  Fastx::Fasta::Reader.open("#{DATA}/genome_oneline.fasta") do |reader|
    reader.each { |_name, seq| bytes += seq.size }
  end
  bytes
end

# --- FASTQ ---
measure("fastq (each)", "#{DATA}/reads.fastq") do
  bytes = 0i64
  Fastx::Fastq::Reader.open("#{DATA}/reads.fastq") do |reader|
    reader.each { |_id, seq, _q| bytes += seq.size }
  end
  bytes
end

measure("fastq (each_bytes)", "#{DATA}/reads.fastq") do
  bytes = 0i64
  Fastx::Fastq::Reader.open("#{DATA}/reads.fastq") do |reader|
    reader.each_bytes { |_id, seq, _q| bytes += seq.size }
  end
  bytes
end

measure("fastq.gz (each)", "#{DATA}/reads.fastq.gz") do
  bytes = 0i64
  Fastx::Fastq::Reader.open("#{DATA}/reads.fastq.gz") do |reader|
    reader.each { |_id, seq, _q| bytes += seq.size }
  end
  bytes
end
