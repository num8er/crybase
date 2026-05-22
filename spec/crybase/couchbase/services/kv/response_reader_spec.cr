require "../../../../spec_helper"

private alias KV = CryBase::CouchBase::Services::KV
private alias KVSpec = CryBase::SpecHelpers::KVHelpers
private alias ReaderPeer = KVSpec::ReaderPeer

describe KV::ResponseReader do
  it "decodes a successful GET response with extras, key, and value" do
    io = IO::Memory.new
    flags = Bytes.new(4)
    IO::ByteFormat::BigEndian.encode(0_u32, flags)
    KVSpec.encode_response(io,
      opcode: KV::Opcode::Get.value,
      status: KV::Status::Success.value,
      cas: 0xCAFE_u64,
      extras: flags,
      key: "k",
      value: "world".to_slice,
    )
    io.rewind

    resp = ReaderPeer.new(io).call

    resp.opcode.should eq(KV::Opcode::Get.value)
    resp.status.should eq(KV::Status::Success)
    resp.cas.should eq(0xCAFE_u64)
    resp.key.should eq("k")
    resp.value.should eq("world".to_slice)
    resp.success?.should be_true
  end

  it "decodes a KeyNotFound response (no body)" do
    io = IO::Memory.new
    KVSpec.encode_response(io,
      opcode: KV::Opcode::Get.value,
      status: KV::Status::KeyNotFound.value,
    )
    io.rewind

    resp = ReaderPeer.new(io).call
    resp.status.should eq(KV::Status::KeyNotFound)
    resp.success?.should be_false
  end

  it "raises on invalid magic" do
    io = IO::Memory.new
    io.write_byte(0xFF_u8)
    23.times { io.write_byte(0_u8) }
    io.rewind

    expect_raises(IO::Error, /invalid KV response magic/) do
      ReaderPeer.new(io).call
    end
  end

  it "raises on unknown status code" do
    io = IO::Memory.new
    KVSpec.encode_response(io,
      opcode: KV::Opcode::Get.value,
      status: 0xFFFE_u16,
    )
    io.rewind

    expect_raises(IO::Error, /unknown KV status/) do
      ReaderPeer.new(io).call
    end
  end
end
