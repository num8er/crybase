module CryBase::CouchBase::Services::KV
  def self.vbucket_id(key : String, count : UInt16 = Constants::VBUCKET_COUNT) : UInt16
    raise ArgumentError.new("vbucket count must be greater than 0") if count == 0

    crc = Digest::CRC32.checksum(key.to_slice)
    (((crc >> 16) & 0x7fff) % count).to_u16
  end
end
