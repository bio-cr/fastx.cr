require "./spec_helper"

describe Fastx do
  it "has a version number" do
    (Fastx::VERSION).should be_a(String)
  end

  it "should open a fasta file" do
    reader = Fastx.open(Path[__DIR__, "fixtures/moo.fa"], "r")
    c = 0
    reader.as(Fastx::Fasta::Reader).each do |name, sequence|
      name.should eq ["chr1 1", "chr2 2"][c]
      sequence.size.should eq [1000, 900][c]
      s = sequence.to_s
      s.starts_with?([CHR1_START, CHR2_START][c]).should be_true
      s.ends_with?([CHR1_END, CHR2_END][c]).should be_true
      c += 1
    end
    reader.close
  end

  it "should open a fasta file with block" do
    Fastx.open(Path[__DIR__, "fixtures/moo.fa"], "r") do |reader|
      c = 0
      reader.as(Fastx::Fasta::Reader).each do |name, sequence|
        name.should eq ["chr1 1", "chr2 2"][c]
        sequence.size.should eq [1000, 900][c]
        s = sequence.to_s
        s.starts_with?([CHR1_START, CHR2_START][c]).should be_true
        s.ends_with?([CHR1_END, CHR2_END][c]).should be_true
        c += 1
      end
    end
  end

  it "should open a fastq file" do
    reader = Fastx.open(Path[__DIR__, "fixtures/moo.fq"], "r")
    c = 0
    reader.as(Fastx::Fastq::Reader).each do |id, sequence, quality|
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

  it "should open a fastq file with a block" do
    Fastx.open(Path[__DIR__, "fixtures/moo.fq"], "r") do |reader|
      c = 0
      reader.as(Fastx::Fastq::Reader).each do |id, sequence, quality|
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

  it "should write a fasta file" do
    tempfile = File.tempfile("quack.fa")
    writer = Fastx.open(tempfile.path, "w").as(Fastx::Fasta::Writer)
    writer.write("chr1 1", "A" * 10)
    writer.write("chr2 2", "C" * 9)
    writer.close
    File.read(tempfile.path)
      .should eq(">chr1 1\nAAAAAAAAAA\n>chr2 2\nCCCCCCCCC\n")
    tempfile.delete
  end

  it "should write a fastq file" do
    tempfile = File.tempfile("quack.fq")
    writer = Fastx.open(tempfile.path, "w").as(Fastx::Fastq::Writer)
    writer.write("chr1_106_509:0/1", "A" * 10, "5" * 10)
    writer.write("chr2_437_492:1/1", "C" * 9, "!" * 9)
    writer.close
    File.read(tempfile.path)
      .should eq("@chr1_106_509:0/1\nAAAAAAAAAA\n+\n5555555555\n@chr2_437_492:1/1\nCCCCCCCCC\n+\n!!!!!!!!!\n")
    tempfile.delete
  end

  it "should open file with format specification" do
    tempfile = File.tempfile("test_file")

    # Write as FASTA using format parameter
    Fastx.open(tempfile.path, "w", Fastx::Format::FASTA) do |writer|
      writer.as(Fastx::Fasta::Writer).write("test", "ACGT")
    end

    # Read as FASTA using format parameter
    Fastx.open(tempfile.path, "r", Fastx::Format::FASTA) do |reader|
      reader.as(Fastx::Fasta::Reader).each do |name, sequence|
        name.should eq "test"
        sequence.to_s.should eq "ACGT"
      end
    end

    tempfile.delete
  end

  it "should raise UnsupportedFormatError for unknown format" do
    expect_raises(Fastx::UnsupportedFormatError, "Unknown format: unknown_file.xyz") do
      Fastx.open("unknown_file.xyz", "r")
    end
  end

  it "should normalize base characters (default: iupac=false)" do
    # Standard bases
    Fastx.normalize_base(65u8).should eq 65u8  # A
    Fastx.normalize_base(97u8).should eq 65u8  # a -> A
    Fastx.normalize_base(67u8).should eq 67u8  # C
    Fastx.normalize_base(99u8).should eq 67u8  # c -> C
    Fastx.normalize_base(71u8).should eq 71u8  # G
    Fastx.normalize_base(103u8).should eq 71u8 # g -> G
    Fastx.normalize_base(84u8).should eq 84u8  # T
    Fastx.normalize_base(116u8).should eq 84u8 # t -> T
    Fastx.normalize_base(78u8).should eq 78u8  # N
    Fastx.normalize_base(110u8).should eq 78u8 # n -> N

    # IUPAC codes should be converted to N when iupac=false (default)
    Fastx.normalize_base(82u8).should eq 78u8  # R -> N
    Fastx.normalize_base(114u8).should eq 78u8 # r -> N
    Fastx.normalize_base(89u8).should eq 78u8  # Y -> N
    Fastx.normalize_base(121u8).should eq 78u8 # y -> N

    # Unknown characters should be converted to N
    Fastx.normalize_base(88u8).should eq 78u8 # X -> N (unknown)
    Fastx.normalize_base(90u8).should eq 78u8 # Z -> N (unknown)
    Fastx.normalize_base(49u8).should eq 78u8 # 1 -> N (unknown)
  end

  it "should normalize base characters with iupac=true" do
    # Standard bases
    Fastx.normalize_base(65u8, iupac: true).should eq 65u8  # A
    Fastx.normalize_base(97u8, iupac: true).should eq 65u8  # a -> A
    Fastx.normalize_base(67u8, iupac: true).should eq 67u8  # C
    Fastx.normalize_base(99u8, iupac: true).should eq 67u8  # c -> C
    Fastx.normalize_base(71u8, iupac: true).should eq 71u8  # G
    Fastx.normalize_base(103u8, iupac: true).should eq 71u8 # g -> G
    Fastx.normalize_base(84u8, iupac: true).should eq 84u8  # T
    Fastx.normalize_base(116u8, iupac: true).should eq 84u8 # t -> T
    Fastx.normalize_base(78u8, iupac: true).should eq 78u8  # N
    Fastx.normalize_base(110u8, iupac: true).should eq 78u8 # n -> N

    # IUPAC ambiguous bases
    Fastx.normalize_base(82u8, iupac: true).should eq 82u8  # R (A or G)
    Fastx.normalize_base(114u8, iupac: true).should eq 82u8 # r -> R
    Fastx.normalize_base(89u8, iupac: true).should eq 89u8  # Y (C or T)
    Fastx.normalize_base(121u8, iupac: true).should eq 89u8 # y -> Y
    Fastx.normalize_base(83u8, iupac: true).should eq 83u8  # S (G or C)
    Fastx.normalize_base(115u8, iupac: true).should eq 83u8 # s -> S
    Fastx.normalize_base(87u8, iupac: true).should eq 87u8  # W (A or T)
    Fastx.normalize_base(119u8, iupac: true).should eq 87u8 # w -> W
    Fastx.normalize_base(75u8, iupac: true).should eq 75u8  # K (G or T)
    Fastx.normalize_base(107u8, iupac: true).should eq 75u8 # k -> K
    Fastx.normalize_base(77u8, iupac: true).should eq 77u8  # M (A or C)
    Fastx.normalize_base(109u8, iupac: true).should eq 77u8 # m -> M
    Fastx.normalize_base(66u8, iupac: true).should eq 66u8  # B (C or G or T)
    Fastx.normalize_base(98u8, iupac: true).should eq 66u8  # b -> B
    Fastx.normalize_base(68u8, iupac: true).should eq 68u8  # D (A or G or T)
    Fastx.normalize_base(100u8, iupac: true).should eq 68u8 # d -> D
    Fastx.normalize_base(72u8, iupac: true).should eq 72u8  # H (A or C or T)
    Fastx.normalize_base(104u8, iupac: true).should eq 72u8 # h -> H
    Fastx.normalize_base(86u8, iupac: true).should eq 86u8  # V (A or C or G)
    Fastx.normalize_base(118u8, iupac: true).should eq 86u8 # v -> V

    # Unknown characters should be converted to N
    Fastx.normalize_base(88u8, iupac: true).should eq 78u8 # X -> N (unknown)
    Fastx.normalize_base(90u8, iupac: true).should eq 78u8 # Z -> N (unknown)
    Fastx.normalize_base(49u8, iupac: true).should eq 78u8 # 1 -> N (unknown)
  end

  it "should support strict base normalization" do
    expect_raises(Fastx::InvalidBaseError) do
      Fastx.normalize_base('X'.ord.to_u8, strict: true)
    end
  end

  it "should encode bases (default: iupac=false)" do
    # Standard bases
    result = Fastx.encode_bases("AcGtN")
    result.should eq Slice[65u8, 67u8, 71u8, 84u8, 78u8] # ACGTN

    # IUPAC codes should be converted to N when iupac=false (default)
    result_iupac = Fastx.encode_bases("RySwKm")
    result_iupac.should eq Slice[78u8, 78u8, 78u8, 78u8, 78u8, 78u8] # NNNNNN

    # Mixed case with IUPAC codes
    result_mixed = Fastx.encode_bases("AcGtRyN")
    result_mixed.should eq Slice[65u8, 67u8, 71u8, 84u8, 78u8, 78u8, 78u8] # ACGTNNN
  end

  it "should encode bases with iupac=true" do
    # Standard bases
    result = Fastx.encode_bases("AcGtN", iupac: true)
    result.should eq Slice[65u8, 67u8, 71u8, 84u8, 78u8] # ACGTN

    # IUPAC codes
    result_iupac = Fastx.encode_bases("RySwKmBdHv", iupac: true)
    result_iupac.should eq Slice[82u8, 89u8, 83u8, 87u8, 75u8, 77u8, 66u8, 68u8, 72u8, 86u8] # RYSWKMBDHV

    # Mixed case IUPAC codes
    result_mixed = Fastx.encode_bases("AcGtRyN", iupac: true)
    result_mixed.should eq Slice[65u8, 67u8, 71u8, 84u8, 82u8, 89u8, 78u8] # ACGTRYN
  end

  it "should decode bases" do
    # Standard bases
    result = Fastx.decode_bases([65u8, 67u8, 71u8, 84u8, 78u8])
    result.should eq "ACGTN"

    # IUPAC codes
    result_iupac = Fastx.decode_bases([82u8, 89u8, 83u8, 87u8, 75u8, 77u8, 66u8, 68u8, 72u8, 86u8])
    result_iupac.should eq "RYSWKMBDHV"

    # Mixed standard and IUPAC codes
    result_mixed = Fastx.decode_bases([65u8, 67u8, 71u8, 84u8, 82u8, 89u8, 78u8])
    result_mixed.should eq "ACGTRYN"
  end

  it "should encode and decode phred scores (default offset 33)" do
    quality = "IIIIHGF"
    scores = Fastx.encode_phred(quality)
    scores.should eq [40_u8, 40_u8, 40_u8, 40_u8, 39_u8, 38_u8, 37_u8]
    decoded = Fastx.decode_phred(scores)
    decoded.should eq quality
  end

  it "should encode and decode phred scores with offset 64" do
    quality = "dddd"
    scores = Fastx.encode_phred(quality, offset: 64)
    scores.should eq [36_u8, 36_u8, 36_u8, 36_u8]
    decoded = Fastx.decode_phred(scores, offset: 64)
    decoded.should eq quality
  end

  it "should work with Format enum for FASTQ" do
    tempfile = File.tempfile("test_file")

    # Write as FASTQ using format parameter
    Fastx.open(tempfile.path, "w", Fastx::Format::FASTQ) do |writer|
      writer.as(Fastx::Fastq::Writer).write("test", "ACGT", "!!!!")
    end

    # Read as FASTQ using format parameter
    Fastx.open(tempfile.path, "r", Fastx::Format::FASTQ) do |reader|
      reader.as(Fastx::Fastq::Reader).each do |id, sequence, quality|
        id.should eq "test"
        sequence.to_s.should eq "ACGT"
        quality.to_s.should eq "!!!!"
      end
    end

    tempfile.delete
  end
end
