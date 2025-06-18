require "./spec_helper"

describe Fastx::Fastq::Writer do
  it "should write a fastq file" do
    tempfile = File.tempfile("quack.fq")
    writer = Fastx::Fastq::Writer.new(tempfile.path)
    writer.write("chr1_106_509:0/1", "A" * 10, "5" * 10)
    writer.write("chr2_437_492:1/1", "C" * 9, "!" * 9)
    writer.closed?.should be_false
    writer.close
    writer.closed?.should be_true
    File.read(tempfile.path)
      .should eq("@chr1_106_509:0/1\nAAAAAAAAAA\n+\n5555555555\n@chr2_437_492:1/1\nCCCCCCCCC\n+\n!!!!!!!!!\n")
    tempfile.delete
  end

  it "should write a fastq file with a block" do
    tempfile = File.tempfile("quack.fq")
    Fastx::Fastq::Writer.open(tempfile.path) do |writer|
      writer.write("chr1_106_509:0/1", "A" * 10, "5" * 10)
      writer.write("chr2_437_492:1/1", "C" * 9, "!" * 9)
    end
    File.read(tempfile.path)
      .should eq("@chr1_106_509:0/1\nAAAAAAAAAA\n+\n5555555555\n@chr2_437_492:1/1\nCCCCCCCCC\n+\n!!!!!!!!!\n")
    tempfile.delete
  end

  it "should write a gzip compressed fastq file" do
    tempfile = File.tempfile("quack.fq.gz")
    writer = Fastx::Fastq::Writer.new(tempfile.path)
    writer.write("chr1_106_509:0/1", "A" * 10, "5" * 10)
    writer.write("chr2_437_492:1/1", "C" * 9, "!" * 9)
    writer.close

    # Read back the gzipped file to verify
    reader = Fastx::Fastq::Reader.new(tempfile.path)
    c = 0
    reader.each do |id, sequence, quality|
      id.should eq ["chr1_106_509:0/1", "chr2_437_492:1/1"][c]
      sequence.to_s.should eq [("A" * 10), ("C" * 9)][c]
      quality.to_s.should eq [("5" * 10), ("!" * 9)][c]
      c += 1
    end
    reader.close
    tempfile.delete
  end
end
