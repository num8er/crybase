module CryBase::CouchBase::Services::KV
  # Mixin that writes `request.to_buffer` to the includer's `@socket`.
  # The includer is expected to own an IO-typed `@socket`.
  #
  # Used together with `ResponseReader` and `Bucket` to compose
  # `KV::Client`. Stateless on its own.
  #
  # ```
  # class Peer
  #   include KV::RequestWriter
  #
  #   def initialize(@socket : IO)
  #   end
  # end
  # ```
  module RequestWriter
    private def write(request : Request) : Nil
      @socket.write(request.to_buffer)
      @socket.flush
    end
  end
end
