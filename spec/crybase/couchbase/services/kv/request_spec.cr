require "../../../../spec_helper"

private alias KV = CryBase::CouchBase::Services::KV

describe KV::Request do
  it "constructs with required opcode and default fields" do
    req = KV::Request.new(KV::Opcode::Get)
    req.opcode.should eq(KV::Opcode::Get)
    req.key.should eq("")
    req.extras.should eq(Bytes.empty)
    req.value.should eq(Bytes.empty)
    req.cas.should eq(0_u64)
    req.opaque.should eq(0_u32)
    req.vbucket.should eq(0_u16)
  end

  it "stores all fields when provided" do
    req = KV::Request.new(
      KV::Opcode::Set,
      key: "k",
      value: "v".to_slice,
      cas: 5_u64,
      opaque: 9_u32,
      vbucket: 475_u16,
    )
    req.opcode.should eq(KV::Opcode::Set)
    req.key.should eq("k")
    req.value.should eq("v".to_slice)
    req.cas.should eq(5_u64)
    req.opaque.should eq(9_u32)
    req.vbucket.should eq(475_u16)
  end

  it "accepts binary key bytes" do
    req = KV::Request.new(KV::Opcode::Get, key: Bytes[0x81, 0x01, 0x6b])

    req.key.should eq(Bytes[0x81, 0x01, 0x6b])
  end

  it "serializes itself through RequestBuffer" do
    req = KV::Request.new(KV::Opcode::Get, key: "hello", opaque: 7_u32)

    req.to_buffer.should eq(KV::RequestBuffer.make(req))
  end
end
