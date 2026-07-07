module CryBase::SpecHelpers::KVHelpers
  private alias KV = CryBase::CouchBase::Services::KV
  private alias CB = CryBase::CouchBase

  record Request,
    opcode : UInt8,
    vbucket : UInt16,
    key : String,
    opaque : UInt32

  record Server,
    endpoint : CB::Endpoint,
    requests : Channel(Request),
    server : TCPServer do
    def close : Nil
      server.close
    rescue
    end
  end

  def self.start_server(request_count : Int32) : Server
    requests = Channel(Request).new(request_count)
    server = TCPServer.new("127.0.0.1", 0)
    endpoint = CB::Endpoint.new("127.0.0.1", server.local_address.port, CB::Service::KV, false)

    spawn do
      socket = server.accept
      begin
        request_count.times do
          request = read_request(socket)
          requests.send(request)
          encode_response(
            socket,
            request.opcode,
            KV::Status::Success.value,
            value: response_value(request.opcode),
          )
          socket.flush
        end
      ensure
        socket.close rescue nil
        server.close rescue nil
      end
    rescue IO::Error | Socket::Error
    end

    Server.new(endpoint, requests, server)
  end

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

  private def self.read_request(io : IO) : Request
    header = Bytes.new(KV::Constants::HEADER_SIZE)
    io.read_fully(header)

    key_size = IO::ByteFormat::BigEndian.decode(UInt16, header[2, 2])
    extras_size = header[4].to_i
    vbucket = IO::ByteFormat::BigEndian.decode(UInt16, header[6, 2])
    body_size = IO::ByteFormat::BigEndian.decode(UInt32, header[8, 4])
    opaque = IO::ByteFormat::BigEndian.decode(UInt32, header[12, 4])
    body = Bytes.new(body_size)
    io.read_fully(body) unless body.empty?

    key = if key_size > 0
            String.new(body[extras_size, key_size])
          else
            ""
          end
    Request.new(header[1], vbucket, key, opaque)
  end

  private def self.response_value(opcode : UInt8) : Bytes
    return Bytes.empty unless opcode.in?({KV::Opcode::Increment.value, KV::Opcode::Decrement.value})

    value = Bytes.new(8)
    IO::ByteFormat::BigEndian.encode(1_u64, value)
    value
  end
end
