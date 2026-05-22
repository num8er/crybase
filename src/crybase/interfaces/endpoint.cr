module CryBase::Interfaces
  # Common contract every database-specific endpoint in CryBase must
  # satisfy. Subtypes add their own service/role metadata and stringification
  # rules on top of this base.
  #
  # ```
  # ep = CryBase::CouchBase::Endpoint.new("localhost", 11210, CryBase::CouchBase::Service::KV, false)
  # ep.is_a?(CryBase::Interfaces::Endpoint) # => true
  # ep.host                                 # => "localhost"
  # ep.port                                 # => 11210
  # ep.tls?                                 # => false
  # ```
  abstract struct Endpoint
    abstract def host : String
    abstract def port : Int32
    abstract def tls? : Bool
  end
end
