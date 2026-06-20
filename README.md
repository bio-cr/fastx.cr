# Fastx.cr

[![test](https://github.com/bio-cr/fastx.cr/actions/workflows/ci.yml/badge.svg)](https://github.com/bio-cr/fastx.cr/actions/workflows/ci.yml)
[![Docs Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://bio-cr.github.io/fastx.cr/)

Small FASTA/FASTQ I/O for Crystal.

## Installation

Add this to `shard.yml`:

```yaml
dependencies:
  fastx:
    github: bio-cr/fastx.cr
```

Then run:

```sh
shards install
```

## What It Does

- Read FASTA
- Read FASTQ
- Write FASTA
- Write FASTQ
- Auto-handle gzip when the path ends with `.gz`
- Stream large files with low-allocation readers

## Read FASTA

```crystal
require "fastx"

Fastx::Fasta::Reader.open("reads.fa.gz") do |reader|
  reader.each do |header, sequence|
    puts "#{header}\t#{sequence.bytesize}"
  end
end
```

`#each` yields owned `String` values. Use `#each_bytes` for lower-allocation
iteration with borrowed `Bytes`:

```crystal
Fastx::Fasta::Reader.open("reads.fa") do |reader|
  reader.each_bytes do |header, sequence|
    # header and sequence are borrowed Bytes (Slice(UInt8)),
    # valid only until the next iteration.
    puts "#{String.new(header)}\t#{sequence.size}"
  end
end
```

For large genomes you can stream each record line by line with
`#each_record_lines`, which never accumulates the full sequence in memory:

```crystal
Fastx::Fasta::Reader.open("genome.fa") do |reader|
  reader.each_record_lines do |name, lines|
    length = 0
    lines.each do |line| # line is borrowed Bytes, valid until the next line
      length += line.size
    end
    puts "#{name}\t#{length}"
  end
end
```

## Read FASTQ

```crystal
Fastx::Fastq::Reader.open("reads.fq.gz") do |reader|
  reader.each do |identifier, sequence, quality|
    puts "#{identifier}\t#{sequence.bytesize}\t#{quality.bytesize}"
  end
end
```

Use `#each_bytes` if you want borrowed `Bytes`:

```crystal
Fastx::Fastq::Reader.open("reads.fq") do |reader|
  reader.each_bytes do |identifier, sequence, quality|
    # All three are borrowed Bytes, valid only until the next iteration.
    puts "#{String.new(identifier)}\t#{sequence.size}\t#{quality.size}"
  end
end
```

`#each_record_lines` streams each record's sequence and quality line by line.
The quality field ends once its length matches the sequence, so the sequence
stream is consumed before quality (automatically, if you skip it):

```crystal
Fastx::Fastq::Reader.open("long_reads.fq") do |reader|
  reader.each_record_lines do |identifier, sequence, quality|
    seq_len = 0
    sequence.each { |line| seq_len += line.size }
    quality.each { |line| process(line) } # borrowed Bytes, copy to retain
    puts "#{identifier}\t#{seq_len}"
  end
end
```

## Write FASTA

```crystal
Fastx::Fasta::Writer.open("out.fa", line_width: 80) do |writer|
  writer.write("seq1", "ACGTACGT")
  writer.write("seq2", "TTTTCCCC")
end
```

Set `line_width: nil` to write one sequence line per record.

## Write FASTQ

```crystal
Fastx::Fastq::Writer.open("out.fq.gz") do |writer|
  writer.write("seq1", "ACGT", "!!!!")
  writer.write("seq2", "TTTT", "####")
end
```

`Fastx::Fastq::Writer` raises `ArgumentError` if sequence and quality lengths differ.

## Use Existing IO

Path-based APIs auto-detect gzip from the filename. IO-based APIs do not.

```crystal
io = IO::Memory.new("@seq1\nACGT\n+\n!!!!\n")
reader = Fastx::Fastq::Reader.new(io)

reader.each do |identifier, sequence, quality|
  puts "#{identifier}\t#{sequence}\t#{quality}"
end
```

```crystal
io = IO::Memory.new
writer = Fastx::Fasta::Writer.new(io, line_width: 4)
writer.write("seq1", "ACGTGG")
puts io.to_s
```

## Format Detection

`Fastx.open` is a convenience API based on file extension:

```crystal
Fastx.open("reads.fa") do |reader|
  reader.as(Fastx::Fasta::Reader).each do |header, sequence|
    puts "#{header}\t#{sequence.bytesize}"
  end
end
```

You can also pass the format explicitly:

```crystal
Fastx.open("output", "w", Fastx::Format::FASTQ) do |writer|
  writer.as(Fastx::Fastq::Writer).write("seq1", "ACGT", "!!!!")
end
```

## Behavior And Limits

- `Reader#each` yields owned `String` values you can store safely.
- `Reader#each_bytes` yields borrowed `Bytes` (`Slice(UInt8)`) and reuses internal buffers for performance.
- `Reader#each_record_lines` streams each record line by line as borrowed `Bytes` without accumulating the full sequence (FASTQ also exposes the quality lines).
- Values yielded by `#each_bytes` / `#each_record_lines` are only valid until the next iteration; copy them (`String.new(bytes)` / `bytes.dup`) to retain them.
- Readers are one-pass. Create a new reader to read again.
- Reader and writer instances are not thread-safe.
- `Fastx::Fastq::Reader#each` / `#each_bytes` support four-line FASTQ records only. `#each_record_lines` also handles multi-line (wrapped) FASTA and FASTQ.
- FASTQ reader and writer validate sequence/quality length equality.

## Base Encoding

```crystal
encoded = Fastx.encode_bases("AcGtNxyz")
decoded = Fastx.decode_bases(encoded)
```

Unknown bases are normalized to `N` by default. Use `strict: true` to raise:

```crystal
Fastx.normalize_base('X'.ord.to_u8, strict: true)
```

## Quality Encoding

```crystal
scores = Fastx.encode_phred("IIIIHGF")
quality = Fastx.decode_phred(scores)
```

## License

MIT License
