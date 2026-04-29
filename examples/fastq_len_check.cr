require "../src/fastx"

if ARGV.size != 1
  STDERR.puts "Usage: #{PROGRAM_NAME} <reads.fq|reads.fq.gz>"
  exit 1
end

path = ARGV[0]
count = 0

begin
  Fastx::Fastq::Reader.open(path) do |reader|
    reader.each do |identifier, sequence, quality|
      count += 1
      puts "#{identifier}\t#{sequence.bytesize}\t#{quality.bytesize}"
    end
  end

  STDERR.puts "OK: #{count} records"
rescue ex : Fastx::InvalidFormatError
  STDERR.puts ex.message
  exit 2
end
