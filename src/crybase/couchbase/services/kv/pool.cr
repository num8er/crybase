module CryBase::CouchBase::Services::KV
  # Fixed-size pool of authenticated KV clients for concurrent fibers.
  class Pool
    ClientDelegator.delegate_to_client

    DEFAULT_SIZE = 10

    # Builds a KV endpoint from *uri* and opens a pool of authenticated
    # clients for the first host in the connection string.
    #
    # `username`, `password`, and `bucket` may be passed explicitly or
    # embedded as `couchbase://user:pass@host/bucket`. Query parameters
    # currently supported by this helper: `tls_verify` and `tls_hostname`.
    #
    # ```
    # pool = KV::Pool.from_string("couchbase://user:pass@node1/default")
    # ```
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
    ) : Pool
      connection_string = ConnectionString.parse(uri)

      new(
        Endpoint.from_string(uri, Service::KV),
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

    getter endpoint : Endpoint
    getter bucket : String
    getter scope : String
    getter collection : String
    getter size : Int32

    @available : Channel(Client)
    @clients : Array(Client)
    @mutex : Mutex
    @closed : Bool

    def initialize(
      @endpoint : Endpoint,
      username : String,
      password : String,
      @bucket : String,
      @size : Int32 = DEFAULT_SIZE,
      connect_timeout : Time::Span = 5.seconds,
      *,
      tls_verify : Bool = true,
      tls_hostname : String? = nil,
      tls_context : OpenSSL::SSL::Context::Client? = nil,
    )
      raise ArgumentError.new("pool size must be at least 1") if @size < 1

      @available = Channel(Client).new(@size)
      @clients = [] of Client
      @scope = Constants::DEFAULT_SCOPE
      @collection = Constants::DEFAULT_COLLECTION
      @mutex = Mutex.new
      @closed = false

      build_clients(username, password, connect_timeout, tls_verify, tls_hostname, tls_context)
    end

    def bucket=(name : String) : String
      raise ArgumentError.new("kv bucket required") if name.empty?

      clients = active_clients
      clients.each(&.bucket=(name))
      @mutex.synchronize do
        raise_closed! if @closed
        @bucket = name
      end
      name
    end

    def scope=(name : String) : String
      raise ArgumentError.new("kv scope required") if name.empty?

      clients = active_clients
      clients.each(&.scope=(name))
      @mutex.synchronize do
        raise_closed! if @closed
        @scope = name
      end
      name
    end

    def collection=(name : String) : String
      raise ArgumentError.new("kv collection required") if name.empty?

      clients = active_clients
      clients.each(&.collection=(name))
      @mutex.synchronize do
        raise_closed! if @closed
        @collection = name
      end
      name
    end

    def scope(name : String) : ScopeContext(Pool)
      ScopeContext.new(self, scope: name)
    end

    def collection(name : String) : CollectionContext(Pool)
      CollectionContext.new(self, scope: @scope, collection: name)
    end

    def collection_id(scope : String, collection : String) : UInt32
      checkout do |client|
        client.collection_id(scope, collection)
      end
    end

    private def build_clients(
      username : String,
      password : String,
      connect_timeout : Time::Span,
      tls_verify : Bool,
      tls_hostname : String?,
      tls_context : OpenSSL::SSL::Context::Client?,
    ) : Nil
      @size.times do
        client = Client.new(
          @endpoint,
          username,
          password,
          @bucket,
          connect_timeout,
          tls_verify: tls_verify,
          tls_hostname: tls_hostname,
          tls_context: tls_context,
        )
        @clients << client
        @available.send(client)
      end
    rescue ex
      @clients.each(&.close)
      raise ex
    end

    def checkout(& : Client -> T) : T forall T
      raise_closed! if closed?

      client = @available.receive
      if closed?
        client.close
        raise_closed!
      end

      begin
        prepare_client(client)
        yield client
      ensure
        if closed?
          client.close
        else
          @available.send(client)
        end
      end
    end

    def close : Nil
      should_close = @mutex.synchronize do
        next false if @closed

        @closed = true
        true
      end

      return unless should_close
      @clients.each(&.close)
    end

    def closed? : Bool
      @mutex.synchronize { @closed }
    end

    private def active_clients : Array(Client)
      @mutex.synchronize do
        raise_closed! if @closed
        @clients.dup
      end
    end

    private def prepare_client(client : Client) : Nil
      client.bucket = @bucket unless client.bucket == @bucket
      client.scope = @scope
      client.collection = @collection
    end

    private def raise_closed! : NoReturn
      raise IO::Error.new("KV pool is closed")
    end

    private def self.required(value : String?, name : String) : String
      value || raise ArgumentError.new("#{name} required")
    end
  end
end
