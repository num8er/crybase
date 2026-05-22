module CryBase::CouchBase::Services::KV
  def self.counter_extras(delta : UInt64, initial : UInt64, expiry : UInt32) : Bytes
    buffer = Bytes.new(Constants::COUNTER_EXTRAS_SIZE)
    IO::ByteFormat::BigEndian.encode(delta, buffer[0, 8])
    IO::ByteFormat::BigEndian.encode(initial, buffer[8, 8])
    IO::ByteFormat::BigEndian.encode(expiry, buffer[16, 4])
    buffer
  end

  def self.counter_value(value : Bytes) : UInt64
    raise IO::Error.new("invalid KV counter response size #{value.size}") unless value.size == 8

    IO::ByteFormat::BigEndian.decode(UInt64, value)
  end
end
