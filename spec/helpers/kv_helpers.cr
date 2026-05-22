module CryBase::SpecHelpers::KVHelpers
  private alias KV = CryBase::CouchBase::Services::KV

  def self.encode_response(
    io : IO,
    opcode : UInt8,
    status : UInt16,
    *,
    cas : UInt64 = 0_u64,
    extras : Bytes = Bytes.empty,
    key : String = "",
    value : Bytes = Bytes.empty,
  ) : Nil
    key_bytes = key.to_slice
    total_body = extras.size + key_bytes.size + value.size
    io.write_byte(KV::Constants::RESPONSE_MAGIC)
    io.write_byte(opcode)
    io.write_bytes(key_bytes.size.to_u16, IO::ByteFormat::BigEndian)
    io.write_byte(extras.size.to_u8)
    io.write_byte(0_u8)
    io.write_bytes(status, IO::ByteFormat::BigEndian)
    io.write_bytes(total_body.to_u32, IO::ByteFormat::BigEndian)
    io.write_bytes(0_u32, IO::ByteFormat::BigEndian)
    io.write_bytes(cas, IO::ByteFormat::BigEndian)
    io.write(extras) unless extras.empty?
    io.write(key_bytes) unless key_bytes.empty?
    io.write(value) unless value.empty?
  end
end
