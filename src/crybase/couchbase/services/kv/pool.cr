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
      @mutex = Mutex.new
      @closed = false

      build_clients(username, password, connect_timeout, tls_verify, tls_hostname, tls_context)
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

    private def raise_closed! : NoReturn
      raise IO::Error.new("KV pool is closed")
    end

    private def self.required(value : String?, name : String) : String
      value || raise ArgumentError.new("#{name} required")
    end
  end
end
