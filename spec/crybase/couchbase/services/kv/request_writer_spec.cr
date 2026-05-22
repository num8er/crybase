require "../../../../spec_helper"

private alias KV = CryBase::CouchBase::Services::KV
private alias KVSpec = CryBase::SpecHelpers::KVHelpers
private alias WriterPeer = KVSpec::WriterPeer

describe KV::RequestWriter do
  it "writes the request buffer and flushes" do
    io = IO::Memory.new
    req = KV::Request.new(KV::Opcode::Get, key: "hello", opaque: 7_u32)

    WriterPeer.new(io).call(req)

    io.rewind
    io.to_slice.should eq(req.to_buffer)
  end
end
