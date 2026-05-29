module CryBase::CouchBase::Services::Query
  class Cluster
    getter seeds : Array(Endpoint)
    getter management_seeds : Array(Endpoint)

    @active_index : Int32?
    @closed : Bool
    @endpoints : Array(Endpoint)
    @mutex : Mutex
    @topology_loaded : Bool

    def active_endpoint : Endpoint?
      @mutex.synchronize do
        index = @active_index
        index ? @endpoints[index]? : nil
      end
    end

    def endpoints : Array(Endpoint)
      @mutex.synchronize { @endpoints.dup }
    end

    def self.from_string(
      uri : String,
      username : String? = nil,
      password : String? = nil,
      connect_timeout : Time::Span = Client::DEFAULT_CONNECT_TIMEOUT,
      read_timeout : Time::Span = Client::DEFAULT_READ_TIMEOUT,
      write_timeout : Time::Span = Client::DEFAULT_WRITE_TIMEOUT,
      *,
      tls_verify : Bool? = nil,
      tls_hostname : String? = nil,
      tls_context : OpenSSL::SSL::Context::Client? = nil,
      discover_topology : Bool = true,
      management_port : Int32? = nil,
      network : String? = nil,
    ) : Cluster
      connection_string = ConnectionString.parse(uri)

      new(
        seed_endpoints(connection_string),
        required(username || connection_string.username, "username"),
        required(password || connection_string.password, "password"),
        connect_timeout,
        read_timeout,
        write_timeout,
        tls_verify: tls_verify.nil? ? connection_string.bool_param("tls_verify", true) : tls_verify,
        tls_hostname: tls_hostname || connection_string.param("tls_hostname"),
        tls_context: tls_context,
        management_seeds: management_endpoints(connection_string, management_port),
        discover_topology: discover_topology,
        network: network || connection_string.param("network"),
      )
    end

    def self.seed_endpoints(connection_string : ConnectionString) : Array(Endpoint)
      management_uri = management_scheme?(connection_string)
      default_port =
        if management_uri
          Service::Query.default_port(connection_string.tls?)
        else
          connection_string.explicit_port || Service::Query.default_port(connection_string.tls?)
        end
      connection_string.hosts.map_with_index do |host, index|
        port = management_uri ? default_port : connection_string.ports[index] || default_port
        Endpoint.new(host, port, Service::Query, connection_string.tls?)
      end
    end

    def self.management_endpoints(
      connection_string : ConnectionString,
      port_override : Int32? = nil,
    ) : Array(Endpoint)
      management_uri = management_scheme?(connection_string)
      default_port = port_override || Service::Management.default_port(connection_string.tls?)

      connection_string.hosts.map_with_index do |host, index|
        port =
          if port_override
            port_override
          elsif management_uri
            connection_string.ports[index] || default_port
          else
            default_port
          end
        Endpoint.new(host, port, Service::Management, connection_string.tls?)
      end
    end

    def self.management_endpoints(seed_endpoints : Array(Endpoint)) : Array(Endpoint)
      endpoints = [] of Endpoint
      seed_endpoints.each do |endpoint|
        management = Endpoint.new(
          endpoint.host,
          Service::Management.default_port(endpoint.tls?),
          Service::Management,
          endpoint.tls?,
        )
        endpoints << management unless endpoints.includes?(management)
      end
      endpoints
    end

    def initialize(
      @seeds : Array(Endpoint),
      @username : String,
      @password : String,
      @connect_timeout : Time::Span = Client::DEFAULT_CONNECT_TIMEOUT,
      @read_timeout : Time::Span = Client::DEFAULT_READ_TIMEOUT,
      @write_timeout : Time::Span = Client::DEFAULT_WRITE_TIMEOUT,
      *,
      @tls_verify : Bool = true,
      @tls_hostname : String? = nil,
      @tls_context : OpenSSL::SSL::Context::Client? = nil,
      management_seeds : Array(Endpoint)? = nil,
      @discover_topology : Bool = false,
      @network : String? = nil,
    )
      raise ArgumentError.new("at least one Query seed endpoint required") if @seeds.empty?

      @management_seeds = management_seeds || self.class.management_endpoints(@seeds)
      @endpoints = @seeds.dup
      @active_index = 0
      @closed = false
      @mutex = Mutex.new
      @topology_loaded = false
    end

    def query(statement : String, *positional_args, **kwargs) : Result
      load_topology_once
      attempts = 0
      max_attempts = query_attempts
      last_error = nil

      while attempts < max_attempts
        attempts += 1
        index = active_index
        client = client_for(endpoint_at(index))

        begin
          return client.query(statement, *positional_args, **kwargs)
        rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error
          last_error = ex
          failover(index)
          refresh_topology_if_available
        rescue ex : Error
          raise ex unless ex.retryable?

          last_error = ex
          failover(index)
          refresh_topology_if_available
        ensure
          client.try(&.close)
        end
      end

      raise last_error || IO::Error.new("no Query seed endpoints available")
    end

    def refresh_topology : Array(Endpoint)
      topology = fetch_topology
      raise IO::Error.new("no Query endpoints found in Couchbase topology") if topology.empty?

      replace_endpoints(topology.endpoints)
    end

    def close : Nil
      @mutex.synchronize do
        @closed = true
        @active_index = nil
      end
    end

    def closed? : Bool
      @mutex.synchronize { @closed }
    end

    private def active_index : Int32
      @mutex.synchronize do
        raise_closed! if @closed
        @active_index || raise IO::Error.new("no Query seed endpoints available")
      end
    end

    private def query_attempts : Int32
      @mutex.synchronize do
        raise_closed! if @closed
        attempts = @endpoints.size
        attempts += @management_seeds.size + 1 if @discover_topology
        attempts
      end
    end

    private def endpoint_at(index : Int32) : Endpoint
      @mutex.synchronize do
        raise_closed! if @closed
        @endpoints[index]
      end
    end

    private def failover(failed_index : Int32) : Nil
      @mutex.synchronize do
        return if @closed
        return unless @active_index == failed_index

        @active_index = (failed_index + 1) % @endpoints.size
      end
    end

    private def client_for(endpoint : Endpoint) : Client
      Client.new(
        endpoint,
        @username,
        @password,
        @connect_timeout,
        @read_timeout,
        @write_timeout,
        tls_verify: @tls_verify,
        tls_hostname: @tls_hostname,
        tls_context: @tls_context,
      )
    end

    private def fetch_topology : Topology
      last_error = nil

      @management_seeds.each do |endpoint|
        begin
          return TopologyClient.new(
            endpoint,
            @username,
            @password,
            @connect_timeout,
            @read_timeout,
            @write_timeout,
            tls_verify: @tls_verify,
            tls_hostname: @tls_hostname,
            tls_context: @tls_context,
            network: @network,
          ).fetch
        rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error | JSON::ParseException
          last_error = ex
        end
      end

      raise last_error || IO::Error.new("no Couchbase management endpoints available for Query topology")
    end

    private def replace_endpoints(endpoints : Array(Endpoint)) : Array(Endpoint)
      @mutex.synchronize do
        raise_closed! if @closed
        @endpoints = endpoints
        @active_index = 0
        @topology_loaded = true
        @endpoints.dup
      end
    end

    private def load_topology_once : Nil
      should_load = @mutex.synchronize do
        raise_closed! if @closed
        @discover_topology && !@topology_loaded
      end
      return unless should_load

      refresh_topology
    rescue IO::Error | Socket::Error | OpenSSL::SSL::Error | JSON::ParseException
      @mutex.synchronize { @topology_loaded = true unless @closed }
    end

    private def refresh_topology_if_available : Nil
      return unless @discover_topology

      refresh_topology
    rescue IO::Error | Socket::Error | OpenSSL::SSL::Error | JSON::ParseException
    end

    private def raise_closed! : NoReturn
      raise IO::Error.new("Query cluster is closed")
    end

    private def self.management_scheme?(connection_string : ConnectionString) : Bool
      connection_string.scheme.in?({"http", "https"})
    end

    private def self.required(value : String?, name : String) : String
      value || raise ArgumentError.new("#{name} required")
    end
  end
end
