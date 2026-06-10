require "../../../spec_helper"

private alias KV = CryBase::CouchBase::KV

describe KV do
  it "pins documented opcode values" do
    KV::Opcode::Get.value.should eq(0x00_u8)
    KV::Opcode::Set.value.should eq(0x01_u8)
    KV::Opcode::Delete.value.should eq(0x04_u8)
    KV::Opcode::Increment.value.should eq(0x05_u8)
    KV::Opcode::Decrement.value.should eq(0x06_u8)
    KV::Opcode::Touch.value.should eq(0x1C_u8)
    KV::Opcode::GetAndTouch.value.should eq(0x1D_u8)
    KV::Opcode::Hello.value.should eq(0x1F_u8)
    KV::Opcode::SaslAuth.value.should eq(0x21_u8)
    KV::Opcode::GetCollectionsManifest.value.should eq(0xBA_u8)
    KV::Opcode::SelectBucket.value.should eq(0x89_u8)
  end

  it "pins documented status values" do
    KV::Status::Success.value.should eq(0x0000_u16)
    KV::Status::KeyNotFound.value.should eq(0x0001_u16)
    KV::Status::KeyExists.value.should eq(0x0002_u16)
    KV::Status::AuthError.value.should eq(0x0020_u16)
    KV::Status::TempFailure.value.should eq(0x0086_u16)
  end

  it "pins protocol framing constants" do
    KV::Constants::REQUEST_MAGIC.should eq(0x80_u8)
    KV::Constants::RESPONSE_MAGIC.should eq(0x81_u8)
    KV::Constants::HEADER_SIZE.should eq(24)
    KV::Constants::FEATURE_SELECT_BUCKET.should eq(0x0008_u16)
    KV::Constants::FEATURE_COLLECTIONS.should eq(0x0012_u16)
    KV::Constants::DEFAULT_SCOPE.should eq("_default")
    KV::Constants::DEFAULT_COLLECTION.should eq("_default")
    KV::Constants::DEFAULT_COLLECTION_ID.should eq(0_u32)
    KV::Constants::VBUCKET_COUNT.should eq(1024_u16)
    KV::Constants::EXPIRY_EXTRAS_SIZE.should eq(4)
    KV::Constants::COUNTER_EXTRAS_SIZE.should eq(20)
  end

  it "maps document keys to Couchbase vbuckets" do
    KV.vbucket_id("crybase:hello").should eq(475_u16)
    KV.vbucket_id("crybase:demo").should eq(1009_u16)
  end

  it "encodes counter extras as delta, initial, expiry" do
    extras = KV.counter_extras(3_u64, 10_u64, 60_u32)

    extras.size.should eq(KV::Constants::COUNTER_EXTRAS_SIZE)
    IO::ByteFormat::BigEndian.decode(UInt64, extras[0, 8]).should eq(3_u64)
    IO::ByteFormat::BigEndian.decode(UInt64, extras[8, 8]).should eq(10_u64)
    IO::ByteFormat::BigEndian.decode(UInt32, extras[16, 4]).should eq(60_u32)
  end

  it "encodes expiry extras" do
    extras = KV.expiry_extras(60_u32)

    extras.size.should eq(KV::Constants::EXPIRY_EXTRAS_SIZE)
    IO::ByteFormat::BigEndian.decode(UInt32, extras).should eq(60_u32)
  end

  it "decodes counter response values" do
    buffer = Bytes.new(8)
    IO::ByteFormat::BigEndian.encode(42_u64, buffer)

    KV.counter_value(buffer).should eq(42_u64)
  end

  it "rejects invalid counter response sizes" do
    expect_raises(IO::Error, /counter response size/) do
      KV.counter_value(Bytes[1, 2, 3])
    end
  end

  it "encodes collection ids as unsigned LEB128" do
    KV.unsigned_leb128(0_u32).should eq(Bytes[0x00])
    KV.unsigned_leb128(127_u32).should eq(Bytes[0x7f])
    KV.unsigned_leb128(128_u32).should eq(Bytes[0x80, 0x01])
    KV.unsigned_leb128(300_u32).should eq(Bytes[0xac, 0x02])
  end

  it "prefixes collection ids to document keys" do
    KV.collection_key(300_u32, "user:1").should eq(Bytes[
      0xac, 0x02,
      0x75, 0x73, 0x65, 0x72, 0x3a, 0x31,
    ])
  end
end
