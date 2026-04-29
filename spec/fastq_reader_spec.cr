require "./spec_helper"

describe Fastx::Fastq::Reader do
  it "should read a fastq file" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    c = 0
    reader.each do |id, sequence, quality|
      id.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"][c]
      sequence.size.should eq 100
      quality.size.should eq 100
      s = sequence.to_s
      s.should eq [FQ_SEQ_1, FQ_SEQ_2][c]
      q = quality.to_s
      q.should eq [FQ_QUAL_1, FQ_QUAL_2][c]
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
        s = sequence.to_s
        s.should eq [FQ_SEQ_1, FQ_SEQ_2][c]
        q = quality.to_s
        q.should eq [FQ_QUAL_1, FQ_QUAL_2][c]
        c += 1
      end
    end
  end

  it "should raise InvalidFormatError for invalid identifier line" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "invalid_identifier\nACGT\n+\n!!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidFormatError) do
      reader.each do |id, sequence, quality|
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
      reader.each do |id, sequence, quality|
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
      reader.each do |id, sequence, quality|
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
      reader.each do |id, sequence, quality|
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
      reader.each do |id, sequence, quality|
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
      reader.each do |id, sequence, quality|
      end
    end
    reader.close
    tempfile.delete
  end

  it "should read a fastq file with each_copy" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    c = 0
    reader.each_copy do |id, sequence, quality|
      id.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"][c]
      sequence.size.should eq 100
      quality.size.should eq 100
      sequence.should be_a(String)
      quality.should be_a(String)
      sequence.should eq [FQ_SEQ_1, FQ_SEQ_2][c]
      quality.should eq [FQ_QUAL_1, FQ_QUAL_2][c]
      c += 1
    end
    reader.close
  end

  it "should open a fastq file with block using each_copy" do
    Fastx::Fastq::Reader.open(Path[__DIR__, "fixtures/moo.fq"]) do |reader|
      c = 0
      reader.each_copy do |id, sequence, quality|
        id.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"][c]
        sequence.size.should eq 100
        quality.size.should eq 100
        sequence.should be_a(String)
        quality.should be_a(String)
        sequence.should eq [FQ_SEQ_1, FQ_SEQ_2][c]
        quality.should eq [FQ_QUAL_1, FQ_QUAL_2][c]
        c += 1
      end
    end
  end

  it "should raise InvalidFormatError for invalid identifier line with each_copy" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "invalid_identifier\nACGT\n+\n!!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidFormatError) do
      reader.each_copy do |id, sequence, quality|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidFormatError for invalid plus line with each_copy" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "@test\nACGT\ninvalid_plus\n!!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidFormatError) do
      reader.each_copy do |id, sequence, quality|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidCharacterError for non-ASCII characters in sequence with each_copy" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "@test\nACGT\u{1F600}ACGT\n+\n!!!!!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidCharacterError) do
      reader.each_copy do |id, sequence, quality|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidCharacterError for non-ASCII characters in quality with each_copy" do
    tempfile = File.tempfile("invalid.fq")
    File.write(tempfile.path, "@test\nACGTACGT\n+\n!!!\u{1F600}!!!\n")

    reader = Fastx::Fastq::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidCharacterError) do
      reader.each_copy do |id, sequence, quality|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should preserve copied strings across iterations" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    ids = [] of String
    sequences = [] of String
    qualities = [] of String

    reader.each_copy do |id, sequence, quality|
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
    reader.each_copy do |id, sequence, quality|
      records << {id, sequence, quality}
    end

    records.should eq([{ "test", "ACGT", "!!!!" }])
    reader.close
  end

  it "should be one-pass" do
    reader = Fastx::Fastq::Reader.new(Path[__DIR__, "fixtures/moo.fq"])
    reader.each { |id, sequence, quality| }

    expect_raises(Fastx::ReaderConsumedError) do
      reader.each { |id, sequence, quality| }
    end

    reader.close
  end
end
