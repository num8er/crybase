module CryBase::CouchBase::Services::KV
  def self.collection_key(collection_id : UInt32, key : String) : Bytes
    prefix = unsigned_leb128(collection_id)
    key_bytes = key.to_slice
    bytes = Bytes.new(prefix.size + key_bytes.size)
    prefix.copy_to(bytes[0, prefix.size])
    key_bytes.copy_to(bytes[prefix.size, key_bytes.size])
    bytes
  end

  def self.unsigned_leb128(value : UInt32) : Bytes
    bytes = [] of UInt8
    current = value

    loop do
      byte = (current & 0x7f_u32).to_u8
      current >>= 7
      byte |= 0x80_u8 unless current.zero?
      bytes << byte
      break if current.zero?
    end

    encoded = Bytes.new(bytes.size)
    bytes.each_with_index do |byte, index|
      encoded[index] = byte
    end
    encoded
  end
end
