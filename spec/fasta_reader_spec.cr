require "./spec_helper"

describe Fastx::Fasta::Reader do
  it "should read a fasta file" do
    reader = Fastx::Fasta::Reader.new(Path[__DIR__, "fixtures/moo.fa"])
    c = 0
    reader.each do |name, sequence|
      name.should eq ["chr1 1", "chr2 2"][c]
      sequence.size.should eq [1000, 900][c]
      sequence.starts_with?([CHR1_START, CHR2_START][c]).should be_true
      sequence.ends_with?([CHR1_END, CHR2_END][c]).should be_true
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
        sequence.starts_with?([CHR1_START, CHR2_START][c]).should be_true
        sequence.ends_with?([CHR1_END, CHR2_END][c]).should be_true
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
      sequence.starts_with?([CHR1_START, CHR2_START][c]).should be_true
      sequence.ends_with?([CHR1_END, CHR2_END][c]).should be_true
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

  it "should raise InvalidFormatError when the first line is not a header" do
    io = IO::Memory.new("comment\n>seq1\nACGT\n")
    reader = Fastx::Fasta::Reader.new(io)

    expect_raises(Fastx::InvalidFormatError, /Header line must start with '>'/) do
      reader.each do |_, _|
      end
    end

    reader.close
  end

  it "should read a fasta file with each_bytes" do
    reader = Fastx::Fasta::Reader.new(Path[__DIR__, "fixtures/moo.fa"])
    c = 0

    reader.each_bytes do |name, sequence|
      name.should be_a(Bytes)
      sequence.should be_a(Bytes)
      String.new(name).should eq ["chr1 1", "chr2 2"][c]
      sequence.size.should eq [1000, 900][c]
      c += 1
    end

    reader.close
  end

  it "should stream a fasta file with each_record_lines" do
    reader = Fastx::Fasta::Reader.new(Path[__DIR__, "fixtures/moo.fa"])
    starts = [] of String
    lengths = [] of Int32

    reader.each_record_lines do |name, lines|
      starts << name
      length = 0
      lines.each do |line|
        length += line.size
      end
      lengths << length
    end

    starts.should eq ["chr1 1", "chr2 2"]
    lengths.should eq [1000, 900]
    reader.close
  end

  it "should stream a gzip compressed fasta file with each_record_lines" do
    reader = Fastx::Fasta::Reader.new(Path[__DIR__, "fixtures/moo.fa.gz"])
    lengths = [] of Int32

    reader.each_record_lines do |_, lines|
      length = 0
      lines.each do |line|
        length += line.size
      end
      lengths << length
    end

    lengths.should eq [1000, 900]
    reader.close
  end

  it "should drain unread lines after each_record_lines block" do
    io = IO::Memory.new(">seq1\nAC\nGT\n>seq2\nTT\n")
    reader = Fastx::Fasta::Reader.new(io)
    names = [] of String

    reader.each_record_lines do |name, _|
      names << name
    end

    names.should eq ["seq1", "seq2"]
    reader.close
  end

  it "should raise InvalidCharacterError from each_record_lines for non-ASCII characters" do
    tempfile = File.tempfile("invalid.fa")
    File.write(tempfile.path, ">test\nACGT\u{1F600}ACGT\n")

    reader = Fastx::Fasta::Reader.new(tempfile.path)
    expect_raises(Fastx::InvalidCharacterError) do
      reader.each_record_lines do |_, lines|
        lines.each do |_|
          # This should raise an exception
        end
      end
    end
    reader.close
    tempfile.delete
  end

  it "should raise InvalidFormatError from each_record_lines when the first line is not a header" do
    io = IO::Memory.new("comment\n>seq1\nACGT\n")
    reader = Fastx::Fasta::Reader.new(io)

    expect_raises(Fastx::InvalidFormatError, /Header line must start with '>'/) do
      reader.each_record_lines do |_, _|
      end
    end

    reader.close
  end

  it "should support reading from IO::Memory" do
    io = IO::Memory.new(">seq1\nAC\nGT\n>seq2\nTT\n")
    reader = Fastx::Fasta::Reader.new(io)
    records = [] of Tuple(String, String)

    reader.each do |name, sequence|
      records << {name, sequence}
    end

    records.should eq([{"seq1", "ACGT"}, {"seq2", "TT"}])
    reader.close
  end

  it "should leave an IO open unless sync_close is enabled" do
    io = IO::Memory.new(">seq1\nACGT\n")
    reader = Fastx::Fasta::Reader.new(io)

    reader.close

    reader.closed?.should be_true
    io.closed?.should be_false
    expect_raises(IO::Error, "Reader is closed") do
      reader.each { |_, _| }
    end

    reader = Fastx::Fasta::Reader.new(io, sync_close: true)
    reader.close
    io.closed?.should be_true
  end

  it "should support sync_close in the open block" do
    io = IO::Memory.new(">seq1\nACGT\n")

    Fastx::Fasta::Reader.open(io, sync_close: true) do |reader|
      reader.closed?.should be_false
    end

    io.closed?.should be_true
  end

  it "should leave the IO open after an open block by default" do
    io = IO::Memory.new(">seq1\nACGT\n")

    Fastx::Fasta::Reader.open(io) do |reader|
      reader.each { |name, sequence| {name, sequence}.should eq({"seq1", "ACGT"}) }
    end

    io.closed?.should be_false
  end

  it "should report a consumed reader as closed after close" do
    reader = Fastx::Fasta::Reader.new(IO::Memory.new(">seq1\nACGT\n"))
    reader.each { |_, _| }
    reader.close

    expect_raises(IO::Error, "Reader is closed") do
      reader.each { |_, _| }
    end
  end

  it "should read CRLF line endings" do
    io = IO::Memory.new(">seq1\r\nAC\r\nGT\r\n")
    reader = Fastx::Fasta::Reader.new(io)

    reader.each do |name, sequence|
      name.should eq "seq1"
      sequence.should eq "ACGT"
    end

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
