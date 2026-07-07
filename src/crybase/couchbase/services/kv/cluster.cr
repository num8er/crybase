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
    getter vbucket_count : UInt16
    getter scope : String
    getter collection : String
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
      vbucket_count : UInt16? = nil,
      discover_bucket_config : Bool = true,
      management_port : Int32? = nil,
      tls_verify : Bool? = nil,
      tls_hostname : String? = nil,
      tls_context : OpenSSL::SSL::Context::Client? = nil,
    ) : Cluster
      connection_string = ConnectionString.parse(uri)
      resolved_username = required(username || connection_string.username, "username")
      resolved_password = required(password || connection_string.password, "password")
      resolved_bucket = required(bucket || connection_string.bucket, "bucket")
      resolved_tls_verify = tls_verify.nil? ? connection_string.bool_param("tls_verify", true) : tls_verify
      resolved_tls_hostname = tls_hostname || connection_string.param("tls_hostname")
      resolved_vbucket_count = vbucket_count || if discover_bucket_config
        CryBase::CouchBase::Services::KV.discover_vbucket_count(
          CryBase::CouchBase::Services::KV.management_endpoints(connection_string, management_port),
          resolved_username,
          resolved_password,
          resolved_bucket,
          connect_timeout,
          tls_verify: resolved_tls_verify,
          tls_hostname: resolved_tls_hostname,
          tls_context: tls_context,
        )
      end

      new(
        seed_endpoints(connection_string),
        resolved_username,
        resolved_password,
        resolved_bucket,
        size,
        connect_timeout,
        tls_verify: resolved_tls_verify,
        tls_hostname: resolved_tls_hostname,
        tls_context: tls_context,
        vbucket_count: resolved_vbucket_count || Constants::VBUCKET_COUNT,
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
      @vbucket_count : UInt16 = Constants::VBUCKET_COUNT,
    )
      raise ArgumentError.new("at least one KV seed endpoint required") if @seeds.empty?
      raise ArgumentError.new("cluster pool size must be at least 1") if @size < 1
      validate_vbucket_count(@vbucket_count)

      @pool = nil
      @active_index = nil
      @scope = Constants::DEFAULT_SCOPE
      @collection = Constants::DEFAULT_COLLECTION
      @mutex = Mutex.new
      @closed = false
      connect_from(0)
    end

    def bucket=(name : String) : String
      raise ArgumentError.new("kv bucket required") if name.empty?

      pool = @mutex.synchronize do
        raise_closed! if @closed
        @bucket = name
        @pool
      end
      pool.try(&.bucket=(name))
      name
    end

    def vbucket_count=(count : UInt16) : UInt16
      validate_vbucket_count(count)

      pool = @mutex.synchronize do
        raise_closed! if @closed
        @vbucket_count = count
        @pool
      end
      pool.try(&.vbucket_count=(count))
      count
    end

    def scope=(name : String) : String
      raise ArgumentError.new("kv scope required") if name.empty?

      pool = @mutex.synchronize do
        raise_closed! if @closed
        @scope = name
        @pool
      end
      pool.try(&.scope=(name))
      name
    end

    def collection=(name : String) : String
      raise ArgumentError.new("kv collection required") if name.empty?

      pool = @mutex.synchronize do
        raise_closed! if @closed
        @collection = name
        @pool
      end
      pool.try(&.collection=(name))
      name
    end

    def scope(name : String) : ScopeContext(Cluster)
      ScopeContext.new(self, scope: name)
    end

    def collection(name : String) : CollectionContext(Cluster)
      CollectionContext.new(self, scope: @scope, collection: name)
    end

    def collection_id(scope : String, collection : String) : UInt32
      checkout do |client|
        client.collection_id(scope, collection)
      end
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
            vbucket_count: @vbucket_count,
          )
          pool.scope = @scope
          pool.collection = @collection
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

    private def validate_vbucket_count(count : UInt16) : Nil
      raise ArgumentError.new("vbucket count must be greater than 0") if count == 0
    end
  end
end
