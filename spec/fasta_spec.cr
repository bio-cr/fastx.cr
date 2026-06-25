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

  it "should copy records from reader each_bytes to writer" do
    tempfile = File.tempfile("copy.fa")

    Fastx::Fasta::Reader.open(Path[__DIR__, "fixtures/moo.fa"]) do |reader|
      Fastx::Fasta::Writer.open(tempfile.path) do |writer|
        reader.each_bytes do |name, sequence|
          writer.write(name, sequence)
        end
      end
    end

    copied = [] of Tuple(String, String)
    Fastx::Fasta::Reader.open(tempfile.path) do |reader|
      reader.each do |name, sequence|
        copied << {name, sequence}
      end
    end

    copied.size.should eq 2
    copied[0][0].should eq "chr1 1"
    copied[0][1].size.should eq 1000
    copied[0][1].starts_with?(CHR1_START).should be_true
    copied[0][1].ends_with?(CHR1_END).should be_true
    copied[1][0].should eq "chr2 2"
    copied[1][1].size.should eq 900
    copied[1][1].starts_with?(CHR2_START).should be_true
    copied[1][1].ends_with?(CHR2_END).should be_true
  ensure
    tempfile.try &.delete
  end
end
