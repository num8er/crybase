module CryBase::CouchBase::Services::KV
  # Seed-failover KV client backed by one active `KV::Pool`.
  #
  # `Cluster` accepts a multi-host Couchbase connection string, tries each
  # seed host until one authenticated pool connects, and exposes the same
  # document operation surface as `KV::Pool`.
  #
  # This is not vbucket-map routing yet. It is a first cluster layer for
  # seed failover; later routing can replace the single active pool with
  # one pool per node.
  #
  # ```
  # cluster = KV::Cluster.from_string("couchbase://user:pass@n1,n2/default")
  # cluster.set("hello", "world")
  # cluster.close
  # ```
  class Cluster
    ClientDelegator.delegate_to_client

    DEFAULT_SIZE = Pool::DEFAULT_SIZE

    getter seeds : Array(Endpoint)
    getter bucket : String
    getter size : Int32

    @pool : Pool?
    @active_index : Int32?
    @mutex : Mutex
    @closed : Bool

    # Returns the endpoint backing the current active pool, or `nil` if the
    # cluster is closed before any pool was built.
    def active_endpoint : Endpoint?
      @mutex.synchronize do
        index = @active_index
        index ? @seeds[index] : nil
      end
    end

    # Parses *uri*, builds KV seed endpoints for every host in the connection
    # string, and connects to the first reachable/authenticated seed.
    #
    # `username`, `password`, and `bucket` may be passed explicitly or
    # embedded as `couchbase://user:pass@host1,host2/bucket`.
    def self.from_string(
      uri : String,
      username : String? = nil,
      password : String? = nil,
      bucket : String? = nil,
      size : Int32 = DEFAULT_SIZE,
      connect_timeout : Time::Span = 5.seconds,
      *,
      tls_verify : Bool? = nil,
      tls_hostname : String? = nil,
      tls_context : OpenSSL::SSL::Context::Client? = nil,
    ) : Cluster
      connection_string = ConnectionString.parse(uri)

      new(
        seed_endpoints(connection_string),
        required(username || connection_string.username, "username"),
        required(password || connection_string.password, "password"),
        required(bucket || connection_string.bucket, "bucket"),
        size,
        connect_timeout,
        tls_verify: tls_verify.nil? ? connection_string.bool_param("tls_verify", true) : tls_verify,
        tls_hostname: tls_hostname || connection_string.param("tls_hostname"),
        tls_context: tls_context,
      )
    end

    # Builds one KV endpoint per seed host using the connection string's TLS
    # mode and explicit port, when present.
    def self.seed_endpoints(connection_string : ConnectionString) : Array(Endpoint)
      default_port = connection_string.explicit_port || Service::KV.default_port(connection_string.tls?)
      connection_string.hosts.map_with_index do |host, index|
        port = connection_string.ports[index] || default_port
        Endpoint.new(host, port, Service::KV, connection_string.tls?)
      end
    end

    def initialize(
      @seeds : Array(Endpoint),
      @username : String,
      @password : String,
      @bucket : String,
      @size : Int32 = DEFAULT_SIZE,
      @connect_timeout : Time::Span = 5.seconds,
      *,
      @tls_verify : Bool = true,
      @tls_hostname : String? = nil,
      @tls_context : OpenSSL::SSL::Context::Client? = nil,
    )
      raise ArgumentError.new("at least one KV seed endpoint required") if @seeds.empty?
      raise ArgumentError.new("cluster pool size must be at least 1") if @size < 1

      @pool = nil
      @active_index = nil
      @mutex = Mutex.new
      @closed = false
      connect_from(0)
    end

    def checkout(& : Client -> T) : T forall T
      attempts = @seeds.size + 1
      last_error = nil

      attempts.times do
        pool = active_pool

        begin
          return pool.checkout { |client| yield client }
        rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error
          last_error = ex
          failover(pool)
        end
      end

      raise last_error || IO::Error.new("no KV seed endpoints available")
    end

    def close : Nil
      pool = @mutex.synchronize do
        next nil if @closed

        @closed = true
        current = @pool
        @pool = nil
        @active_index = nil
        current
      end

      pool.try(&.close)
    end

    def closed? : Bool
      @mutex.synchronize { @closed }
    end

    private def active_pool : Pool
      pool = @mutex.synchronize do
        raise_closed! if @closed
        @pool
      end

      pool || connect_from(0)
    end

    private def failover(failed_pool : Pool) : Nil
      @mutex.synchronize do
        return if @closed

        current = @pool
        next unless current && current.same?(failed_pool)

        current.close
        @pool = nil
        start_index = if active_index = @active_index
                        active_index + 1
                      else
                        0
                      end
        @active_index = nil
        connect_from_locked(start_index)
      end
    end

    private def connect_from(start_index : Int32) : Pool
      @mutex.synchronize do
        raise_closed! if @closed
        connect_from_locked(start_index)
      end
    end

    private def connect_from_locked(start_index : Int32) : Pool
      last_error = nil

      @seeds.size.times do |offset|
        index = (start_index + offset) % @seeds.size
        endpoint = @seeds[index]

        begin
          pool = Pool.new(
            endpoint,
            @username,
            @password,
            @bucket,
            @size,
            @connect_timeout,
            tls_verify: @tls_verify,
            tls_hostname: @tls_hostname,
            tls_context: @tls_context,
          )
          @pool = pool
          @active_index = index
          return pool
        rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error
          last_error = ex
        end
      end

      raise IO::Error.new("no KV seed endpoints reachable: #{last_error.try(&.message) || "unknown error"}")
    end

    private def raise_closed! : NoReturn
      raise IO::Error.new("KV cluster is closed")
    end

    private def self.required(value : String?, name : String) : String
      value || raise ArgumentError.new("#{name} required")
    end
  end
end
