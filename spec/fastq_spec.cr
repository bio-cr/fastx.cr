require "./spec_helper"

describe Fastx::Fastq do
  it "should open a fastq file" do
    reader = Fastx::Fastq.open(Path[__DIR__, "fixtures/moo.fq"], "r")
    c = 0
    reader.as(Fastx::Fastq::Reader).each do |id, sequence, quality|
      id.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"][c]
      sequence.size.should eq 100
      quality.size.should eq 100
      sequence.should eq [FQ_SEQ_1, FQ_SEQ_2][c]
      quality.should eq [FQ_QUAL_1, FQ_QUAL_2][c]
      c += 1
    end
    reader.close
  end

  it "should open a fastq file with a block" do
    Fastx::Fastq.open(Path[__DIR__, "fixtures/moo.fq"], "r") do |reader|
      c = 0
      reader.as(Fastx::Fastq::Reader).each do |id, sequence, quality|
        id.should eq ["chr1_106_509:0/1", "chr1_437_492:1/1"][c]
        sequence.size.should eq 100
        quality.size.should eq 100
        sequence.should eq [FQ_SEQ_1, FQ_SEQ_2][c]
        quality.should eq [FQ_QUAL_1, FQ_QUAL_2][c]
        c += 1
      end
    end
  end

  it "should write a fastq file" do
    tempfile = File.tempfile("quack.fq")
    writer = Fastx::Fastq.open(tempfile.path, "w")
    writer.as(Fastx::Fastq::Writer).write("chr1_106_509:0/1", "A" * 10, "5" * 10)
    writer.as(Fastx::Fastq::Writer).write("chr2_437_492:1/1", "C" * 9, "!" * 9)
    writer.close
    File.read(tempfile.path)
      .should eq("@chr1_106_509:0/1\nAAAAAAAAAA\n+\n5555555555\n@chr2_437_492:1/1\nCCCCCCCCC\n+\n!!!!!!!!!\n")
    tempfile.delete
  end

  it "should write a fastq file with a block" do
    tempfile = File.tempfile("quack.fq")
    Fastx::Fastq.open(tempfile.path, "w") do |writer|
      writer.as(Fastx::Fastq::Writer).write("chr1_106_509:0/1", "A" * 10, "5" * 10)
      writer.as(Fastx::Fastq::Writer).write("chr2_437_492:1/1", "C" * 9, "!" * 9)
    end
    File.read(tempfile.path)
      .should eq("@chr1_106_509:0/1\nAAAAAAAAAA\n+\n5555555555\n@chr2_437_492:1/1\nCCCCCCCCC\n+\n!!!!!!!!!\n")
    tempfile.delete
  end
end
