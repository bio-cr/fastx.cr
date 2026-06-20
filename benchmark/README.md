# Benchmarks

Throughput and allocation benchmarks for fastx.cr. All scripts must be run
with `--release`.

First generate the (deterministic, synthetic) datasets — written to
`benchmark/data/`, which is git-ignored:

```sh
crystal run --release benchmark/gen_data.cr
```

Then run any of:

```sh
crystal run --release benchmark/bench_reader.cr   # reader throughput + GC allocation
crystal run --release benchmark/bench_writer.cr   # writer throughput
crystal run --release benchmark/bench_helpers.cr  # encode/decode helpers (ips)
```

`bench_reader.cr` reports MB/s over input bytes and bytes allocated per pass
(as a multiple of input size), and compares `#each` (owned `String`) against
`#each_bytes` (borrowed `Bytes`).

Numbers are relative and depend on the machine and file-cache state; compare
runs on the same host.
