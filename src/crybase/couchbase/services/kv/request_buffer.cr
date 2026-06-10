module CryBase::CouchBase::Services::KV
  # Builds binary KV request buffers from `Request` values.
  module RequestBuffer
    def self.make(request : Request) : Bytes
      key_bytes = key_bytes(request.key)
      total_body = request.extras.size + key_bytes.size + request.value.size
      buffer = Bytes.new(Constants::HEADER_SIZE + total_body)

      buffer[0] = Constants::REQUEST_MAGIC
      buffer[1] = request.opcode.value
      IO::ByteFormat::BigEndian.encode(key_bytes.size.to_u16, buffer[2, 2])
      buffer[4] = request.extras.size.to_u8
      buffer[5] = 0_u8
      IO::ByteFormat::BigEndian.encode(request.vbucket, buffer[6, 2])
      IO::ByteFormat::BigEndian.encode(total_body.to_u32, buffer[8, 4])
      IO::ByteFormat::BigEndian.encode(request.opaque, buffer[12, 4])
      IO::ByteFormat::BigEndian.encode(request.cas, buffer[16, 8])

      offset = Constants::HEADER_SIZE
      offset = append(buffer, offset, request.extras)
      offset = append(buffer, offset, key_bytes)
      append(buffer, offset, request.value)

      buffer
    end

    private def self.key_bytes(key : String) : Bytes
      key.to_slice
    end

    private def self.key_bytes(key : Bytes) : Bytes
      key
    end

    private def self.append(buffer : Bytes, offset : Int32, source : Bytes) : Int32
      return offset if source.empty?

      source.copy_to(buffer[offset, source.size])
      offset + source.size
    end
  end
end
