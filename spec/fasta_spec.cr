require "./spec_helper"

describe Fastx::Fasta do
  it "should open a fasta file" do
    reader = Fastx::Fasta.open(Path[__DIR__, "fixtures/moo.fa"], "r")
    c = 0
    reader.as(Fastx::Fasta::Reader).each do |name, sequence|
      name.should eq ["chr1 1", "chr2 2"][c]
      sequence.size.should eq [1000, 900][c]
      sequence.starts_with?(
        [CHR1_START,
         CHR2_START,
        ][c]).should be_true
      sequence.ends_with?(
        [CHR1_END,
         CHR2_END,
        ][c]).should be_true
      c += 1
    end
    reader.close
  end

  it "should open a fasta file with a block" do
    Fastx::Fasta.open(Path[__DIR__, "fixtures/moo.fa"], "r") do |reader|
      c = 0
      reader.as(Fastx::Fasta::Reader).each do |name, sequence|
        name.should eq ["chr1 1", "chr2 2"][c]
        sequence.size.should eq [1000, 900][c]
        sequence.starts_with?([CHR1_START, CHR2_START][c]).should be_true
        sequence.ends_with?([CHR1_END, CHR2_END][c]).should be_true
        c += 1
      end
    end
  end

  it "should write a fasta file" do
    tempfile = File.tempfile("quack.fa")
    writer = Fastx::Fasta.open(tempfile.path, "w")
    writer.as(Fastx::Fasta::Writer).write("chr1 1", "A" * 10)
    writer.as(Fastx::Fasta::Writer).write("chr2 2", "C" * 9)
    writer.close
    File.read(tempfile.path)
      .should eq(">chr1 1\nAAAAAAAAAA\n>chr2 2\nCCCCCCCCC\n")
    tempfile.delete
  end

  it "should write a fasta file with a block" do
    tempfile = File.tempfile("quack.fa")
    Fastx::Fasta.open(tempfile.path, "w") do |writer|
      writer.as(Fastx::Fasta::Writer).write("chr1 1", "A" * 10)
      writer.as(Fastx::Fasta::Writer).write("chr2 2", "C" * 9)
    end
    File.read(tempfile.path)
      .should eq(">chr1 1\nAAAAAAAAAA\n>chr2 2\nCCCCCCCCC\n")
    tempfile.delete
  end
end
