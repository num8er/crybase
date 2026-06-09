module CryBase::CouchBase
  # Cluster-level client that enumerates and probes every Couchbase
  # service interface (KV, Query, Search, Analytics, Index, Eventing,
  # Views, Management) for the configured hosts, over either plaintext
  # or TLS ports.
  #
  # No protocol handshake is performed at this layer — `connect` only
  # validates TCP reachability so callers can confirm the cluster's
  # network surface before driving a service-specific protocol (for
  # example `CryBase::CouchBase::Services::KV::Client`).
  #
  # ```
  # client = CryBase::CouchBase::Client.connect("couchbase://node1,node2")
  # kv_eps = client.endpoints_for(CryBase::CouchBase::Service::KV)
  # client.close
  # ```
  class Client < CryBase::Interfaces::Client
    getter connection_string : ConnectionString
    getter username : String?
    getter password : String?
    getter connect_timeout : Time::Span
    getter endpoints : Array(Endpoint)
    getter? connected : Bool = false

    # Builds the client and immediately calls `connect`. Equivalent to
    # `new(...).tap(&.connect)`.
    #
    # ```
    # client = CryBase::CouchBase::Client.connect(
    #   "couchbases://node1,node2",
    #   username: "Administrator",
    #   password: "s3cret",
    # )
    # ```
    def self.connect(
      uri : String,
      username : String? = nil,
      password : String? = nil,
      connect_timeout : Time::Span = 5.seconds,
    ) : Client
      client = new(uri, username, password, connect_timeout)
      client.connect
      client
    end

    # Parses *uri* and pre-computes the full `endpoints` matrix
    # (one per host × service). No network activity yet.
    def initialize(
      uri : String,
      @username : String? = nil,
      @password : String? = nil,
      @connect_timeout : Time::Span = 5.seconds,
    )
      @connection_string = ConnectionString.parse(uri)
      @endpoints = build_endpoints(@connection_string)
    end

    # Probes every endpoint over TCP and returns the reachable subset.
    # Marks the client as `connected?` if at least one endpoint
    # responded; otherwise raises `IO::Error`.
    #
    # ```
    # reachable = client.connect # => [Endpoint, Endpoint, ...]
    # ```
    def connect : Array(Endpoint)
      reachable = [] of Endpoint
      @endpoints.each do |endpoint|
        reachable << endpoint if probe(endpoint)
      end

      if reachable.empty?
        raise IO::Error.new(
          "no Couchbase service endpoints reachable for hosts " \
          "#{@connection_string.hosts.join(", ")}"
        )
      end

      @connected = true
      reachable
    end

    # Marks the client as no longer `connected?`. This layer holds no
    # persistent sockets, so this is purely a state flip.
    def close : Nil
      @connected = false
    end

    # Returns every `Endpoint` for the given *service*, in host order.
    #
    # ```
    # client.endpoints_for(CryBase::CouchBase::Service::KV).map(&.host)
    # # => ["node1", "node2"]
    # ```
    def endpoints_for(service : Service) : Array(Endpoint)
      @endpoints.select { |e| e.service == service }
    end

    private def build_endpoints(cs : ConnectionString) : Array(Endpoint)
      list = [] of Endpoint
      cs.hosts.each_with_index do |host, index|
        Services.list.each do |service|
          port =
            if service.management? && (port_override = cs.ports[index] || cs.explicit_port)
              port_override
            else
              service.default_port(cs.tls?)
            end
          list << Endpoint.new(host, port, service, cs.tls?)
        end
      end
      list
    end

    private def probe(endpoint : Endpoint) : Bool
      config = CryBase::Connectivity::SocketConfig.new(connect_timeout: @connect_timeout)
      socket = CryBase::Connectivity.open_socket(
        endpoint.host,
        endpoint.port,
        config,
      )
      socket.close
      true
    rescue IO::Error | ::Socket::Error
      false
    end
  end
end
