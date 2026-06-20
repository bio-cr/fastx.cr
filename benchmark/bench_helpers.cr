# Throughput of the module-level encode/decode helpers.
#
#   crystal run --release benchmark/bench_helpers.cr

require "../src/fastx"
require "benchmark"

SEQ    = String.build { |io| 1000.times { io << "ACGTN" } } # 5000 bp
QUAL   = String.build { |io| 5000.times { io << ('!'.ord + rand(40)).chr } }
BASES  = Fastx.encode_bases(SEQ)
SCORES = Fastx.encode_phred(QUAL)

puts "seq length = #{SEQ.bytesize}"

Benchmark.ips do |x|
  x.report("encode_bases") { Fastx.encode_bases(SEQ) }
  x.report("encode_bases (iupac)") { Fastx.encode_bases(SEQ, iupac: true) }
  x.report("decode_bases") { Fastx.decode_bases(BASES) }
  x.report("encode_phred") { Fastx.encode_phred(QUAL) }
  x.report("decode_phred") { Fastx.decode_phred(SCORES) }
end
