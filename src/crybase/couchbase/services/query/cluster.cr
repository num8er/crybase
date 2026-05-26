module CryBase::CouchBase::Services::Query
  class Cluster
    getter seeds : Array(Endpoint)

    @active_index : Int32?
    @closed : Bool
    @mutex : Mutex

    def active_endpoint : Endpoint?
      @mutex.synchronize do
        index = @active_index
        index ? @seeds[index] : nil
      end
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
      )
    end

    def self.seed_endpoints(connection_string : ConnectionString) : Array(Endpoint)
      default_port = connection_string.explicit_port || Service::Query.default_port(connection_string.tls?)
      connection_string.hosts.map_with_index do |host, index|
        port = connection_string.ports[index] || default_port
        Endpoint.new(host, port, Service::Query, connection_string.tls?)
      end
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
    )
      raise ArgumentError.new("at least one Query seed endpoint required") if @seeds.empty?

      @active_index = 0
      @closed = false
      @mutex = Mutex.new
    end

    def query(statement : String, *positional_args, **kwargs) : Result
      attempts = @seeds.size
      last_error = nil

      attempts.times do
        index = active_index
        client = client_for(index)

        begin
          return client.query(statement, *positional_args, **kwargs)
        rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error
          last_error = ex
          failover(index)
        rescue ex : Error
          raise ex unless ex.retryable?

          last_error = ex
          failover(index)
        ensure
          client.try(&.close)
        end
      end

      raise last_error || IO::Error.new("no Query seed endpoints available")
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

    private def failover(failed_index : Int32) : Nil
      @mutex.synchronize do
        return if @closed
        return unless @active_index == failed_index

        @active_index = (failed_index + 1) % @seeds.size
      end
    end

    private def client_for(index : Int32) : Client
      Client.new(
        @seeds[index],
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

    private def raise_closed! : NoReturn
      raise IO::Error.new("Query cluster is closed")
    end

    private def self.required(value : String?, name : String) : String
      value || raise ArgumentError.new("#{name} required")
    end
  end
end
