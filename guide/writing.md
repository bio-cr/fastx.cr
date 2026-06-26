# Writing FASTA and FASTQ

Writers accept `String` and `Bytes` inputs. Path-based writers auto-detect gzip
when the filename ends with `.gz`.

## FASTA

```crystal
require "fastx"

Fastx::Fasta::Writer.open("out.fa", line_width: 80) do |writer|
  writer.write("seq1", "ACGTACGT")
  writer.write("seq2", "TTTTCCCC")
end
```

Set `line_width: nil` to write one sequence line per record:

```crystal
Fastx::Fasta::Writer.open("out.fa", line_width: nil) do |writer|
  writer.write("seq1", "ACGTACGT")
end
```

## FASTQ

```crystal
require "fastx"

Fastx::Fastq::Writer.open("out.fq.gz") do |writer|
  writer.write("seq1", "ACGT", "!!!!")
  writer.write("seq2", "TTTT", "####")
end
```

`Fastx::Fastq::Writer` raises `ArgumentError` if sequence and quality lengths
differ.

## Existing IO

Use `Writer.new(io)` when the destination is already open:

```crystal
io = IO::Memory.new
writer = Fastx::Fasta::Writer.new(io, line_width: 4)
writer.write("seq1", "ACGTGG")
writer.close

puts io.to_s
```

## Bytes

```crystal
io = IO::Memory.new
writer = Fastx::Fastq::Writer.new(io)
writer.write("seq1".to_slice, "ACGT".to_slice, "!!!!".to_slice)
writer.close
```
