module CryBase::CouchBase::Services::KV
  def self.expiry_extras(expiry : UInt32) : Bytes
    buffer = Bytes.new(Constants::EXPIRY_EXTRAS_SIZE)
    IO::ByteFormat::BigEndian.encode(expiry, buffer)
    buffer
  end
end
