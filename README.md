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

## Features

- Read and write FASTA
- Read and write FASTQ
- Auto-handle gzip when the path ends with `.gz`
- Iterate with owned `String` values or lower-allocation borrowed `Bytes`
- Stream large records line by line without accumulating full sequences
- Encode/decode nucleotide bases and FASTQ quality scores

## Quick Start

Read FASTA:

```crystal
require "fastx"

Fastx::Fasta::Reader.open("reads.fa.gz") do |reader|
  reader.each do |header, sequence|
    puts "#{header}\t#{sequence.bytesize}"
  end
end
```

Read FASTQ:

```crystal
Fastx::Fastq::Reader.open("reads.fq.gz") do |reader|
  reader.each do |identifier, sequence, quality|
    puts "#{identifier}\t#{sequence.bytesize}\t#{quality.bytesize}"
  end
end
```

Write FASTA:

```crystal
Fastx::Fasta::Writer.open("out.fa", line_width: 80) do |writer|
  writer.write("seq1", "ACGTACGT")
end
```

Write FASTQ:

```crystal
Fastx::Fastq::Writer.open("out.fq.gz") do |writer|
  writer.write("seq1", "ACGT", "!!!!")
end
```

## Guides

- [Getting started](guides/getting-started.md)
- [Reading FASTA and FASTQ](guides/reading.md)
- [Writing FASTA and FASTQ](guides/writing.md)
- [Streams and limits](guides/streams.md)
- [Base and quality encoding](guides/encoding.md)

## License

MIT License
