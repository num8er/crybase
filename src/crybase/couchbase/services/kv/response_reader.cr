module CryBase::CouchBase::Services::KV
  # Mixin that reads exactly one `Response` packet from the includer's
  # `@socket`. The includer is expected to own an IO-typed `@socket`.
  #
  # Used together with `RequestWriter` and `Bucket` to compose
  # `KV::Client`. Stateless on its own.
  #
  # ```
  # class Peer
  #   include KV::ResponseReader
  #
  #   def initialize(@socket : IO)
  #   end
  # end
  #
  # # `io` already contains a server response packet, positioned at start.
  # resp = Peer.new(io).read
  # ```
  module ResponseReader
    # Reads a 24-byte header off `@socket`, then reads `total_body`
    # bytes, splits them into `extras + key + value`, and returns a
    # `Response`.
    #
    # Raises `IO::Error` if the magic byte doesn't match
    # `Constants::RESPONSE_MAGIC` or the status code is unknown to `Status`.
    private def read : Response
      header = Bytes.new(Constants::HEADER_SIZE)
      @socket.read_fully(header)

      magic = header[0]
      raise IO::Error.new("invalid KV response magic 0x#{magic.to_s(16)}") unless magic == Constants::RESPONSE_MAGIC

      opcode = header[1]
      key_len = IO::ByteFormat::BigEndian.decode(UInt16, header[2, 2])
      extras_len = header[4]
      status_val = IO::ByteFormat::BigEndian.decode(UInt16, header[6, 2])
      total_body = IO::ByteFormat::BigEndian.decode(UInt32, header[8, 4])
      cas = IO::ByteFormat::BigEndian.decode(UInt64, header[16, 8])

      body = total_body.zero? ? Bytes.empty : Bytes.new(total_body)
      @socket.read_fully(body) unless body.empty?

      ext_len = extras_len.to_i
      key_l = key_len.to_i
      extras = body[0, ext_len]
      key_str = String.new(body[ext_len, key_l])
      value_offset = ext_len + key_l
      value = body[value_offset, body.size - value_offset]

      status = Status.from_value?(status_val) ||
               raise IO::Error.new("unknown KV status 0x#{status_val.to_s(16)}")

      Response.new(opcode, status, cas, extras, key_str, value)
    end
  end
end
