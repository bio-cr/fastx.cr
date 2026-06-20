# Changelog

## 0.1.1

### Performance

- Tuned the byte reader and `decode_phred` fast paths while keeping the public
  API unchanged.

## 0.1.0

### API

- `Fasta::Reader#each` / `Fastq::Reader#each` yield owned `String` values.
  This is the safe default when records need to be printed, compared, or stored.
- Added `Fasta::Reader#each_bytes` / `Fastq::Reader#each_bytes` for
  low-allocation iteration with borrowed `Bytes` (`Slice(UInt8)`). The yielded
  slices point into reusable internal buffers and are only valid until the next
  iteration; copy them (`String.new(bytes)` / `bytes.dup`) to retain them.
- `Fastx.encode_bases` accepts `Bytes` and `String`.
- `Fastx.encode_phred` gained a `Bytes` overload.

### Performance

- Readers were rewritten on top of a byte-level buffered line scanner
  (`ByteLines`, using `LibC.memchr` for newline search), replacing
  `IO#each_line`. Borrowed `#each_bytes` iteration avoids per-record `String`
  allocation, while `#each` creates owned `String` records explicitly.
- `decode_bases` / `decode_phred` build the result string directly from bytes.

### Fixes

- CRLF (`\r\n`) line endings are now handled (trailing `\r` is stripped).
