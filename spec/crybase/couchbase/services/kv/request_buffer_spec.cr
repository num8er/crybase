require "../../../../spec_helper"

private alias KV = CryBase::CouchBase::Services::KV

describe KV::RequestBuffer do
  it "builds a 24-byte header followed by extras + key + value" do
    extras = Bytes.new(8)
    IO::ByteFormat::BigEndian.encode(0_u32, extras[0, 4])
    IO::ByteFormat::BigEndian.encode(0_u32, extras[4, 4])
    req = KV::Request.new(
      KV::Opcode::Set,
      key: "foo",
      extras: extras,
      value: "bar".to_slice,
    )

    buffer = req.to_buffer

    buffer.size.should eq(KV::Constants::HEADER_SIZE + 8 + 3 + 3)
  end

  it "encodes the GET header layout" do
    req = KV::Request.new(KV::Opcode::Get, key: "hello", opaque: 7_u32)
    buffer = req.to_buffer
    header = buffer[0, KV::Constants::HEADER_SIZE]

    header[0].should eq(KV::Constants::REQUEST_MAGIC)
    header[1].should eq(KV::Opcode::Get.value)
    IO::ByteFormat::BigEndian.decode(UInt16, header[2, 2]).should eq(5_u16)
    header[4].should eq(0_u8)
    header[5].should eq(0_u8)
    IO::ByteFormat::BigEndian.decode(UInt16, header[6, 2]).should eq(0_u16)
    IO::ByteFormat::BigEndian.decode(UInt32, header[8, 4]).should eq(5_u32)
    IO::ByteFormat::BigEndian.decode(UInt32, header[12, 4]).should eq(7_u32)
    IO::ByteFormat::BigEndian.decode(UInt64, header[16, 8]).should eq(0_u64)

    body = buffer[KV::Constants::HEADER_SIZE, 5]
    String.new(body).should eq("hello")
  end

  it "honors the cas field" do
    req = KV::Request.new(KV::Opcode::Set, key: "k", cas: 0xDEADBEEF_u64)
    header = req.to_buffer[0, KV::Constants::HEADER_SIZE]

    IO::ByteFormat::BigEndian.decode(UInt64, header[16, 8]).should eq(0xDEADBEEF_u64)
  end

  it "honors the opaque field" do
    req = KV::Request.new(KV::Opcode::Get, key: "k", opaque: 42_u32)
    header = req.to_buffer[0, KV::Constants::HEADER_SIZE]

    IO::ByteFormat::BigEndian.decode(UInt32, header[12, 4]).should eq(42_u32)
  end

  it "honors the vbucket field" do
    req = KV::Request.new(KV::Opcode::Get, key: "crybase:hello", vbucket: 475_u16)
    header = req.to_buffer[0, KV::Constants::HEADER_SIZE]

    IO::ByteFormat::BigEndian.decode(UInt16, header[6, 2]).should eq(475_u16)
  end
end
