require "./spec_helper"

describe Fastx::Fasta::Writer do
  it "should write a fasta file" do
    tempfile = File.tempfile("quack.fa")
    writer = Fastx::Fasta::Writer.new(tempfile.path)
    writer.write("chr1 1", "A" * 10)
    writer.write("chr2 2", "C" * 9)
    writer.closed?.should be_false
    writer.close
    writer.closed?.should be_true
    File.read(tempfile.path)
      .should eq(">chr1 1\nAAAAAAAAAA\n>chr2 2\nCCCCCCCCC\n")
    tempfile.delete
  end

  it "should write a fasta file with a block" do
    tempfile = File.tempfile("quack.fa")
    Fastx::Fasta::Writer.open(tempfile.path) do |writer|
      writer.write("chr1 1", "A" * 10)
      writer.write("chr2 2", "C" * 9)
    end
    File.read(tempfile.path)
      .should eq(">chr1 1\nAAAAAAAAAA\n>chr2 2\nCCCCCCCCC\n")
    tempfile.delete
  end

  it "should write a gzip compressed fasta file" do
    tempfile = File.tempfile("quack.fa.gz")
    writer = Fastx::Fasta::Writer.new(tempfile.path)
    writer.write("chr1 1", "A" * 10)
    writer.write("chr2 2", "C" * 9)
    writer.close

    # Read back the gzipped file to verify
    reader = Fastx::Fasta::Reader.new(tempfile.path)
    c = 0
    reader.each do |name, sequence|
      name.should eq ["chr1 1", "chr2 2"][c]
      sequence.should eq [("A" * 10), ("C" * 9)][c]
      c += 1
    end
    reader.close
    tempfile.delete
  end

  it "should wrap fasta sequence lines when line_width is specified" do
    tempfile = File.tempfile("wrapped.fa")
    writer = Fastx::Fasta::Writer.new(tempfile.path, line_width: 4)
    writer.write("chr1 1", "ACGTGG")
    writer.close

    File.read(tempfile.path).should eq(">chr1 1\nACGT\nGG\n")
    tempfile.delete
  end

  it "should write a fasta record from bytes" do
    io = IO::Memory.new
    writer = Fastx::Fasta::Writer.new(io, line_width: 4)
    writer.write("seq1".to_slice, "ACGTGG".to_slice)

    io.to_s.should eq(">seq1\nACGT\nGG\n")
    writer.close
  end

  it "should write a fasta record from mixed string and bytes" do
    io = IO::Memory.new
    writer = Fastx::Fasta::Writer.new(io)
    writer.write("seq1", "ACGT".to_slice)
    writer.write("seq2".to_slice, "TGCA")

    io.to_s.should eq(">seq1\nACGT\n>seq2\nTGCA\n")
    writer.close
  end

  it "should support writing to IO::Memory" do
    io = IO::Memory.new
    writer = Fastx::Fasta::Writer.new(io, line_width: 3)
    writer.write("seq1", "ACGT")

    io.to_s.should eq(">seq1\nACG\nT\n")
    writer.close
  end
end
