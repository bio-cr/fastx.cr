require "./spec_helper"

describe Fastx::Fastq::Reader do
  it "should read a fastq file" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    c = 0
    reader.each do |id, sequence, quality|
      id.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"][c]
      sequence.size.should eq 100
      quality.size.should eq 100
      sequence.should eq [FQ_SEQ_1, FQ_SEQ_2][c]
      quality.should eq [FQ_QUAL_1, FQ_QUAL_2][c]
      c += 1
    end
    reader.close
  end

  it "should open a fastq file with block" do
    Fastx::Fastq::Reader.open(Path[__DIR__, "fixtures/moo.fq"]) do |reader|
      c = 0
      reader.each do |id, sequence, quality|
        id.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"][c]
        sequence.size.should eq 100
        quality.size.should eq 100
        sequence.should eq [FQ_SEQ_1, FQ_SEQ_2][c]
        quality.should eq [FQ_QUAL_1, FQ_QUAL_2][c]
        c += 1
      end
    end
  end

  it "should raise InvalidFormatError for invalid identifier line" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "invalid_identifier\nACGT\n+\n!!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidFormatError) do
      reader.each do |_, _, _|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidFormatError for invalid plus line" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "@test\nACGT\ninvalid_plus\n!!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidFormatError) do
      reader.each do |_, _, _|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidCharacterError for non-ASCII characters in sequence" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "@test\nACGT\u{1F600}ACGT\n+\n!!!!!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidCharacterError) do
      reader.each do |_, _, _|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidCharacterError for non-ASCII characters in quality" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "@test\nACGTACGT\n+\n!!!\u{1F600}!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidCharacterError) do
      reader.each do |_, _, _|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidFormatError when sequence and quality lengths differ" do
    tempfile = File.tempfile("invalid_lengths.fq")
    File.write(tempfile.path, "@test\nACGT\n+\n!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidFormatError, /sequence and quality lengths differ/) do
      reader.each do |_, _, _|
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidFormatError for incomplete four-line fastq records" do
    tempfile = File.tempfile("incomplete.fq")
    File.write(tempfile.path, "@test\nACGT\n+\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidFormatError, /Incomplete FASTQ record/) do
      reader.each do |_, _, _|
      end
    end
    reader.close
    tempfile.delete
  end

  it "should read a fastq file with each_bytes" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    c = 0

    reader.each_bytes do |id, sequence, quality|
      id.should be_a(Bytes)
      sequence.should be_a(Bytes)
      quality.should be_a(Bytes)
      String.new(id).should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"][c]
      sequence.size.should eq 100
      quality.size.should eq 100
      c += 1
    end

    reader.close
  end

  it "should preserve strings across iterations" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    ids = [] of String
    sequences = [] of String
    qualities = [] of String

    reader.each do |id, sequence, quality|
      ids << id
      sequences << sequence
      qualities << quality
    end

    ids.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"]
    sequences.should eq [FQ_SEQ_1, FQ_SEQ_2]
    qualities.should eq [FQ_QUAL_1, FQ_QUAL_2]
    reader.close
  end

  it "should support reading from IO::Memory" do
    io = IO::Memory.new("@test\nACGT\n+\n!!!!\n")
    reader = Fastx::Fastq::Reader.new(io)

    records = [] of Tuple(String, String, String)
    reader.each do |id, sequence, quality|
      records << {id, sequence, quality}
    end

    records.should eq([{"test", "ACGT", "!!!!"}])
    reader.close
  end

  it "should read CRLF line endings" do
    io = IO::Memory.new("@test\r\nACGT\r\n+\r\n!!!!\r\n")
    reader = Fastx::Fastq::Reader.new(io)

    reader.each do |id, sequence, quality|
      id.should eq "test"
      sequence.should eq "ACGT"
      quality.should eq "!!!!"
    end

    reader.close
  end

  it "should be one-pass" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    reader.each { |_, _, _| }

    expect_raises(Fastx::ReaderConsumedError) do
      reader.each { |_, _, _| }
    end

    reader.close
  end

  it "should stream a fastq file with each_record_lines" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    ids = [] of String
    seqs = [] of String
    quals = [] of String

    reader.each_record_lines do |id, sequence, quality|
      ids << id
      seqs << String.build { |builder| sequence.each { |line| builder.write(line) } }
      quals << String.build { |builder| quality.each { |line| builder.write(line) } }
    end

    ids.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"]
    seqs.should eq [FQ_SEQ_1, FQ_SEQ_2]
    quals.should eq [FQ_QUAL_1, FQ_QUAL_2]
    reader.close
  end

  it "should stream multi-line fastq records with each_record_lines" do
    io = IO::Memory.new("@m\nACGT\nACGT\n+\n!!!!\n!!!!\n@n\nGG\nCC\n+\n####\n")
    reader = Fastx::Fastq::Reader.new(io)
    seqs = [] of String
    quals = [] of String

    reader.each_record_lines do |_, sequence, quality|
      seqs << String.build { |builder| sequence.each { |line| builder.write(line) } }
      quals << String.build { |builder| quality.each { |line| builder.write(line) } }
    end

    seqs.should eq ["ACGTACGT", "GGCC"]
    quals.should eq ["!!!!!!!!", "####"]
    reader.close
  end

  it "should drain unread streams after each_record_lines block" do
    io = IO::Memory.new("@a\nACGT\n+\n!!!!\n@b\nTT\n+\n##\n")
    reader = Fastx::Fastq::Reader.new(io)
    ids = [] of String

    reader.each_record_lines do |id, _, _|
      ids << id
    end

    ids.should eq ["a", "b"]
    reader.close
  end

  it "should reconstruct quality even when sequence is not read first" do
    io = IO::Memory.new("@a\nAC\nGT\n+\n!!\n##\n")
    reader = Fastx::Fastq::Reader.new(io)
    qual = ""

    reader.each_record_lines do |_, _, quality|
      qual = String.build { |builder| quality.each { |line| builder.write(line) } }
    end

    qual.should eq "!!##"
    reader.close
  end

  it "should raise when quality is shorter than sequence in each_record_lines" do
    io = IO::Memory.new("@a\nACGTACGT\n+\n!!!!\n")
    reader = Fastx::Fastq::Reader.new(io)

    expect_raises(Fastx::InvalidFormatError, /Incomplete FASTQ record/) do
      reader.each_record_lines do |_, _, quality|
        quality.each { |_| }
      end
    end

    reader.close
  end

  it "should raise when quality is longer than sequence in each_record_lines" do
    io = IO::Memory.new("@a\nACGT\n+\n!!!!!\n")
    reader = Fastx::Fastq::Reader.new(io)

    expect_raises(Fastx::InvalidFormatError, /longer than sequence/) do
      reader.each_record_lines do |_, _, quality|
        quality.each { |_| }
      end
    end

    reader.close
  end

  it "should read CRLF line endings with each_record_lines" do
    io = IO::Memory.new("@test\r\nACGT\r\n+\r\n!!!!\r\n")
    reader = Fastx::Fastq::Reader.new(io)

    reader.each_record_lines do |id, sequence, quality|
      id.should eq "test"
      String.build { |builder| sequence.each { |line| builder.write(line) } }.should eq "ACGT"
      String.build { |builder| quality.each { |line| builder.write(line) } }.should eq "!!!!"
    end

    reader.close
  end

  it "should be one-pass for each_record_lines" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    reader.each_record_lines { |_, _, _| }

    expect_raises(Fastx::ReaderConsumedError) do
      reader.each_record_lines { |_, _, _| }
    end

    reader.close
  end
end
