# Getting Started

## Install

Add Fastx to `shard.yml`:

```yaml
dependencies:
  fastx:
    github: bio-cr/fastx.cr
```

Then run:

```sh
shards install
```

## Read a File

```crystal
require "fastx"

Fastx::Fasta::Reader.open("reads.fa.gz") do |reader|
  reader.each do |name, sequence|
    puts "#{name}\t#{sequence.bytesize}"
  end
end
```

```crystal
Fastx::Fastq::Reader.open("reads.fq.gz") do |reader|
  reader.each do |identifier, sequence, quality|
    puts "#{identifier}\t#{sequence.bytesize}\t#{quality.bytesize}"
  end
end
```

Path-based readers and writers auto-detect gzip when the filename ends with
`.gz`.

## Write a File

```crystal
Fastx::Fasta::Writer.open("out.fa", line_width: 80) do |writer|
  writer.write("seq1", "ACGTACGT")
end
```

```crystal
Fastx::Fastq::Writer.open("out.fq.gz") do |writer|
  writer.write("seq1", "ACGT", "!!!!")
end
```

## Use Format Detection

`Fastx.open` chooses FASTA or FASTQ from the filename extension:

```crystal
Fastx.open("reads.fa") do |reader|
  reader.as(Fastx::Fasta::Reader).each do |name, sequence|
    puts "#{name}\t#{sequence.bytesize}"
  end
end
```

Pass the format explicitly when the extension is not enough:

```crystal
Fastx.open("output", "w", Fastx::Format::FASTQ) do |writer|
  writer.as(Fastx::Fastq::Writer).write("seq1", "ACGT", "!!!!")
end
```

## Use Existing IO

IO-based APIs do not auto-detect gzip. Readers and writers take ownership of
the IO, so closing them also closes the IO object you passed in:

```crystal
io = IO::Memory.new("@seq1\nACGT\n+\n!!!!\n")
reader = Fastx::Fastq::Reader.new(io)

reader.each do |identifier, sequence, quality|
  puts "#{identifier}\t#{sequence}\t#{quality}"
end
```
