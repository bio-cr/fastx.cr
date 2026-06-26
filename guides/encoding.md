# Base and Quality Encoding

## Base Encoding

```crystal
require "fastx"

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
