module CryBase::CouchBase
  # A single addressable Couchbase service interface — the combination
  # of a host, a port, the `Service` running on that port, and whether
  # the connection should be TLS.
  #
  # ```
  # ep = CryBase::CouchBase::Endpoint.new("h1", 11210, CryBase::CouchBase::Service::KV, false)
  # ep.scheme  # => "couchbase"
  # ep.address # => "couchbase://h1:11210"
  # ep.to_s    # => "Data (KV) couchbase://h1:11210"
  # ```
  struct Endpoint < CryBase::Interfaces::Endpoint
    getter host : String
    getter port : Int32
    getter service : Service
    getter? tls : Bool

    def initialize(@host : String, @port : Int32, @service : Service, @tls : Bool)
    end

    # Parses a connection string and returns one concrete endpoint for
    # the first host.
    #
    # Pass *service* to choose a specific Couchbase service. When omitted,
    # `couchbase://` and `couchbases://` strings produce a KV endpoint,
    # while `http://` and `https://` strings produce a Management endpoint.
    # An explicit port in the string overrides the selected service's
    # default port.
    #
    # ```
    # Endpoint.from_string("couchbase://node1").address              # => "couchbase://node1:11210"
    # Endpoint.from_string("couchbases://node1:11217").port          # => 11217
    # Endpoint.from_string("https://node1:18091").service            # => Service::Management
    # Endpoint.from_string("couchbase://node1", Service::Query).port # => 8093
    # ```
    def self.from_string(input : String, service : Service? = nil) : Endpoint
      connection_string = ConnectionString.parse(input)
      selected_service = service || default_service(input)
      port = connection_string.ports.first || connection_string.explicit_port || selected_service.default_port(connection_string.tls?)

      new(connection_string.hosts.first, port, selected_service, connection_string.tls?)
    end

    # The URI scheme appropriate for this endpoint:
    # * `"couchbase"` / `"couchbases"` for the KV service
    # * `"http"` / `"https"` for every other service
    #
    # ```
    # Endpoint.new("host", 11210, Service::KV, false).scheme   # => "couchbase"
    # Endpoint.new("host", 11207, Service::KV, true).scheme    # => "couchbases"
    # Endpoint.new("host", 8093, Service::Query, false).scheme # => "http"
    # ```
    def scheme : String
      case service
      when .kv?
        tls? ? "couchbases" : "couchbase"
      else
        tls? ? "https" : "http"
      end
    end

    # Full `scheme://host:port` string for this endpoint.
    #
    # ```
    # Endpoint.new("host", 11210, Service::KV, false).address # => "couchbase://host:11210"
    # ```
    def address : String
      "#{scheme}://#{host}:#{port}"
    end

    # Renders the endpoint as `"<service display name> <address>"`.
    #
    # ```
    # Endpoint.new("host", 11210, Service::KV, false).to_s # => "Data (KV) couchbase://host:11210"
    # ```
    def to_s(io : IO) : Nil
      io << service.display_name << " " << address
    end

    private def self.default_service(input : String) : Service
      scheme = if idx = input.index("://")
                 input[0...idx].downcase
               else
                 "couchbase"
               end

      scheme.in?({"http", "https"}) ? Service::Management : Service::KV
    end
  end
end
