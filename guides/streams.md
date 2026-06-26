# Streams and Limits

This chapter covers the details that matter when performance, memory use, or
record lifetime is important.

## Owned Strings

`Reader#each` yields owned `String` values. These values are safe to store after
the block advances to the next record.

```crystal
records = [] of Tuple(String, String)

Fastx::Fasta::Reader.open("reads.fa") do |reader|
  reader.each do |name, sequence|
    records << {name, sequence}
  end
end
```

## Borrowed Bytes

`Reader#each_bytes` yields borrowed `Bytes` (`Slice(UInt8)`). Readers reuse
internal buffers for performance, so yielded slices are only valid until the
next iteration.

Copy values you need to retain:

```crystal
ids = [] of String

Fastx::Fastq::Reader.open("reads.fq") do |reader|
  reader.each_bytes do |id, _, _|
    ids << String.new(id)
  end
end
```

## Line Streams

`Reader#each_record_lines` streams record fields line by line as borrowed
`Bytes`. FASTA exposes sequence lines. FASTQ exposes sequence and quality lines.

This is a low-memory API rather than the fastest record-level API. Use it when
you do not want to accumulate an entire sequence or quality field.

## FASTQ Record Shapes

All FASTQ reader methods support conventional four-line FASTQ records:

```text
@read1
ACGT
+
!!!!
```

Wrapped FASTQ records are not supported:

```text
@read1
ACGT
ACGT
+
!!!!
!!!!
```

Use an external normalizer first if you need to read wrapped FASTQ input.

## Reader Lifetime

Readers are one-pass. Create a new reader to read the same source again.

Reader and writer instances are not thread-safe.

## Validation

FASTQ readers and writers validate sequence/quality length equality.

Readers reject non-ASCII sequence and quality lines. Writers assume the caller
passes valid record fields, except for FASTQ sequence/quality length equality.
