module CryBase::CouchBase::Services::KV
  # One outbound packet for the KV service, as a pure value type.
  # `RequestBuffer.make` serializes it; `RequestWriter#write` sends it.
  #
  # ```
  # req = KV::Request.new(KV::Opcode::Get, key: "hello")
  # req.opcode    # => KV::Opcode::Get
  # req.key       # => "hello"
  # req.opaque    # => 0_u32
  # req.to_buffer # => Bytes
  # ```
  #
  # The fields:
  #
  # * *opcode*  — the command code (`Opcode::Get`, `::Set`, etc.)
  # * *key*     — the document/operation key, as UTF-8 text or already encoded
  #               binary key bytes
  # * *extras*  — opcode-specific bytes that precede the body
  # * *value*   — the document/operation body
  # * *cas*     — compare-and-swap token, or `0` for "any"
  # * *opaque*  — caller-controlled echo field; the server returns it
  #               verbatim in the response
  # * *vbucket* — key partition id used by document operations
  record Request,
    opcode : Opcode,
    key : String | Bytes = "",
    extras : Bytes = Bytes.empty,
    value : Bytes = Bytes.empty,
    cas : UInt64 = 0_u64,
    opaque : UInt32 = 0_u32,
    vbucket : UInt16 = 0_u16

  struct Request
    # Serializes this request into one binary KV packet.
    def to_buffer : Bytes
      RequestBuffer.make(self)
    end
  end
end
