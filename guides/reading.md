# Reading FASTA and FASTQ

Fastx readers are one-pass iterators over FASTA or FASTQ records. Choose the
reader method by the shape of data you want:

- `#each` yields owned `String` values.
- `#each_bytes` yields borrowed `Bytes` backed by reader-owned reusable buffers.
- `#each_record_lines` is the lowest-memory streaming API.

See [Streams and limits](streams.md) for lifetime and FASTQ record-shape details.

## FASTA

```crystal
require "fastx"

Fastx::Fasta::Reader.open("reads.fa.gz") do |reader|
  reader.each do |header, sequence|
    puts "#{header}\t#{sequence.bytesize}"
  end
end
```

Use `#each_bytes` when you want the same record-level API with fewer
allocations:

```crystal
Fastx::Fasta::Reader.open("reads.fa") do |reader|
  reader.each_bytes do |header, sequence|
    # header and sequence are borrowed Bytes backed by reader-owned
    # reusable buffers, valid only until the next record.
    puts "#{String.new(header)}\t#{sequence.size}"
  end
end
```

Use `#each_record_lines` for the lowest-memory path when a sequence may be too
large to accumulate:

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

## FASTQ

```crystal
Fastx::Fastq::Reader.open("reads.fq.gz") do |reader|
  reader.each do |identifier, sequence, quality|
    puts "#{identifier}\t#{sequence.bytesize}\t#{quality.bytesize}"
  end
end
```

Use `#each_bytes` for lower-allocation record iteration:

```crystal
Fastx::Fastq::Reader.open("reads.fq") do |reader|
  reader.each_bytes do |identifier, sequence, quality|
    # All three are borrowed Bytes backed by reader-owned reusable buffers,
    # valid only until the next record.
    puts "#{String.new(identifier)}\t#{sequence.size}\t#{quality.size}"
  end
end
```

`#each_record_lines` is the lowest-memory FASTQ reading API. It streams the
sequence line and quality line as borrowed `Bytes`. The sequence line is
consumed before quality automatically if you skip it, so sequence/quality
length equality can still be validated:

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

## Choosing a Method

Use `#each` for straightforward application code. Use `#each_bytes` for
record-level processing where allocations matter and next-record lifetime is
enough. Use `#each_record_lines` for the lowest-memory path when a full FASTA
sequence or a FASTQ sequence/quality line may be too large to copy.
