require "./spec_helper"

describe Fastx::Fasta::Reader do
  it "should read a fasta file" do
    reader = Fastx::Fasta::Reader.new(Path[__DIR__, "fixtures/moo.fa"])
    c = 0
    reader.each do |name, sequence|
      name.should eq ["chr1 1", "chr2 2"][c]
      sequence.size.should eq [1000, 900][c]
      s = sequence.to_s
      s.starts_with?([CHR1_START, CHR2_START][c]).should be_true
      s.ends_with?([CHR1_END, CHR2_END][c]).should be_true
      c += 1
    end
    reader.closed?.should be_false
    reader.close
    reader.closed?.should be_true
  end

  it "should open a fasta file with block" do
    Fastx::Fasta::Reader.open(Path[__DIR__, "fixtures/moo.fa"]) do |reader|
      c = 0
      reader.each do |name, sequence|
        name.should eq ["chr1 1", "chr2 2"][c]
        sequence.size.should eq [1000, 900][c]
        s = sequence.to_s
        s.starts_with?([CHR1_START, CHR2_START][c]).should be_true
        s.ends_with?([CHR1_END, CHR2_END][c]).should be_true
        c += 1
      end
    end
  end

  it "should read a gzip compressed fasta file" do
    reader = Fastx::Fasta::Reader.new(Path[__DIR__, "fixtures/moo.fa.gz"])
    c = 0
    reader.each do |name, sequence|
      name.should eq ["chr1 1", "chr2 2"][c]
      sequence.size.should eq [1000, 900][c]
      s = sequence.to_s
      s.starts_with?([CHR1_START, CHR2_START][c]).should be_true
      s.ends_with?([CHR1_END, CHR2_END][c]).should be_true
      c += 1
    end
    reader.closed?.should be_false
    reader.close
    reader.closed?.should be_true
  end

  it "should raise InvalidCharacterError for non-ASCII characters" do
    tempfile = File.tempfile("invalid.fa")
    File.write(tempfile.path, ">test\nACGT\u{1F600}ACGT\n")

    reader = Fastx::Fasta::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidCharacterError) do
      reader.each do |_, _|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should read a fasta file with each_copy" do
    reader = Fastx::Fasta::Reader.new(Path[__DIR__, "fixtures/moo.fa"])
    c = 0
    reader.each_copy do |name, sequence|
      name.should eq ["chr1 1", "chr2 2"][c]
      sequence.size.should eq [1000, 900][c]
      sequence.should be_a(String)
      sequence.starts_with?([CHR1_START, CHR2_START][c]).should be_true
      sequence.ends_with?([CHR1_END, CHR2_END][c]).should be_true
      c += 1
    end
    reader.close
  end

  it "should open a fasta file with block using each_copy" do
    Fastx::Fasta::Reader.open(Path[__DIR__, "fixtures/moo.fa"]) do |reader|
      c = 0
      reader.each_copy do |name, sequence|
        name.should eq ["chr1 1", "chr2 2"][c]
        sequence.size.should eq [1000, 900][c]
        sequence.should be_a(String)
        sequence.starts_with?([CHR1_START, CHR2_START][c]).should be_true
        sequence.ends_with?([CHR1_END, CHR2_END][c]).should be_true
        c += 1
      end
    end
  end

  it "should raise InvalidCharacterError for non-ASCII characters with each_copy" do
    tempfile = File.tempfile("invalid.fa")
    File.write(tempfile.path, ">test\nACGT\u{1F600}ACGT\n")

    reader = Fastx::Fasta::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidCharacterError) do
      reader.each_copy do |_, _|
        # This should raise an exception
      end
    end
    reader.close
    tempfile.delete
  end

  it "should support reading from IO::Memory" do
    io = IO::Memory.new(">seq1\nAC\nGT\n>seq2\nTT\n")
    reader = Fastx::Fasta::Reader.new(io)
    records = [] of Tuple(String, String)

    reader.each_copy do |name, sequence|
      records << {name, sequence}
    end

    records.should eq([{"seq1", "ACGT"}, {"seq2", "TT"}])
    reader.close
  end

  it "should be one-pass" do
    reader = Fastx::Fasta::Reader.new(Path[__DIR__, "fixtures/moo.fa"])
    reader.each { |_, _| }

    expect_raises(Fastx::ReaderConsumedError) do
      reader.each { |_, _| }
    end

    reader.close
  end
end
