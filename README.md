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

Use `#each_copy` if you need to keep records after the current iteration:

```crystal
Fastx::Fasta::Reader.open("reads.fa") do |reader|
  reader.each_copy do |header, sequence|
    stored_header = header
    stored_sequence = sequence
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

Use `#each_copy` if you need safe `String` copies:

```crystal
Fastx::Fastq::Reader.open("reads.fq") do |reader|
  reader.each_copy do |identifier, sequence, quality|
    saved_id = identifier
    saved_sequence = sequence
    saved_quality = quality
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

reader.each_copy do |identifier, sequence, quality|
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

- `Reader#each` reuses internal buffers for performance.
- Values yielded by `#each` are only valid until the next iteration.
- Use `#each_copy` if you want values you can store safely.
- Readers are one-pass. Create a new reader to read again.
- Reader and writer instances are not thread-safe.
- `Fastx::Fastq::Reader` currently supports four-line FASTQ records only.
- Multi-line FASTQ is not supported.
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
