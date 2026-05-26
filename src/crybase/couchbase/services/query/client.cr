module CryBase::CouchBase::Services::Query
  class Client
    DEFAULT_CONNECT_TIMEOUT = 5.seconds
    DEFAULT_READ_TIMEOUT    = 30.seconds
    DEFAULT_WRITE_TIMEOUT   = 5.seconds
    PATH                    = "/query/service"

    getter endpoint : Endpoint

    @closed : Bool
    @mutex : Mutex

    def self.from_string(
      uri : String,
      username : String? = nil,
      password : String? = nil,
      connect_timeout : Time::Span = DEFAULT_CONNECT_TIMEOUT,
      read_timeout : Time::Span = DEFAULT_READ_TIMEOUT,
      write_timeout : Time::Span = DEFAULT_WRITE_TIMEOUT,
      *,
      tls_verify : Bool? = nil,
      tls_hostname : String? = nil,
      tls_context : OpenSSL::SSL::Context::Client? = nil,
    ) : Client
      connection_string = ConnectionString.parse(uri)

      new(
        Endpoint.from_string(uri, Service::Query),
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

    def initialize(
      @endpoint : Endpoint,
      @username : String,
      @password : String,
      @connect_timeout : Time::Span = DEFAULT_CONNECT_TIMEOUT,
      @read_timeout : Time::Span = DEFAULT_READ_TIMEOUT,
      @write_timeout : Time::Span = DEFAULT_WRITE_TIMEOUT,
      *,
      @tls_verify : Bool = true,
      @tls_hostname : String? = nil,
      @tls_context : OpenSSL::SSL::Context::Client? = nil,
    )
      @closed = false
      @mutex = Mutex.new
    end

    def query(
      statement : String,
      *positional_args,
      named_args = NamedTuple.new,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      options = NamedTuple.new,
      raise_on_error : Bool = true,
    ) : Result
      form = self.class.form(
        statement,
        positional_args,
        named_args,
        readonly,
        scan_consistency,
        client_context_id,
        timeout,
        options,
      )

      @mutex.synchronize do
        raise_closed! if @closed
        execute(form, raise_on_error)
      end
    end

    def close : Nil
      @mutex.synchronize { @closed = true }
    end

    def closed? : Bool
      @mutex.synchronize { @closed }
    end

    def self.form(
      statement : String,
      positional_args,
      named_args,
      readonly : Bool?,
      scan_consistency : ScanConsistency | String | Nil,
      client_context_id : String?,
      timeout : Time::Span?,
      options,
    ) : String
      URI::Params.build do |form|
        form.add("statement", statement)
        form.add("args", positional_args.to_json) unless positional_args.empty?
        add_named_args(form, named_args)
        form.add("readonly", readonly.to_s) unless readonly.nil?
        form.add("scan_consistency", scan_consistency_param(scan_consistency)) if scan_consistency
        form.add("client_context_id", client_context_id) if client_context_id
        form.add("timeout", "#{timeout.total_milliseconds.to_i64}ms") if timeout
        add_options(form, options)
      end
    end

    private def execute(form : String, raise_on_error : Bool) : Result
      client = open_http_client
      begin
        response = client.post(PATH, request_headers, form: form)
        result = Result.from_body(response.body)
        raise Error.new(response.status_code, result) if raise_on_error && (!response.success? || result.error?)

        result
      ensure
        client.close rescue nil
      end
    end

    private def open_http_client : HTTP::Client
      io = open_io
      client = HTTP::Client.new(io, @endpoint.host, @endpoint.port)
      client.basic_auth(@username, @password)
      client
    end

    private def open_io : IO
      config = CryBase::Connectivity::SocketConfig.new(
        tls: @endpoint.tls?,
        connect_timeout: @connect_timeout,
        read_timeout: @read_timeout,
        write_timeout: @write_timeout,
        tls_verify: @tls_verify,
        tls_hostname: @tls_hostname,
        tls_context: @tls_context,
      )
      CryBase::Connectivity.open_socket(
        @endpoint.host,
        @endpoint.port,
        config,
      )
    end

    private def request_headers : HTTP::Headers
      HTTP::Headers{
        "Accept"     => "application/json",
        "Connection" => "close",
      }
    end

    private def raise_closed! : NoReturn
      raise IO::Error.new("Query client is closed")
    end

    private def self.add_named_args(form : URI::Params::Builder, named_args : NamedTuple) : Nil
      named_args.each do |name, value|
        form.add(parameter_name(name), value.to_json)
      end
    end

    private def self.add_named_args(form : URI::Params::Builder, named_args : Hash) : Nil
      named_args.each do |name, value|
        form.add(parameter_name(name), value.to_json)
      end
    end

    private def self.add_options(form : URI::Params::Builder, options : NamedTuple) : Nil
      options.each do |name, value|
        form.add(name.to_s, value.to_s)
      end
    end

    private def self.add_options(form : URI::Params::Builder, options : Hash) : Nil
      options.each do |name, value|
        form.add(name.to_s, value.to_s)
      end
    end

    private def self.parameter_name(name : String | Symbol) : String
      key = name.to_s
      key.starts_with?("$") ? key : "$#{key}"
    end

    private def self.scan_consistency_param(value : ScanConsistency) : String
      value.to_query_param
    end

    private def self.scan_consistency_param(value : String) : String
      value
    end

    private def self.scan_consistency_param(value : Nil) : String
      ""
    end

    private def self.required(value : String?, name : String) : String
      value || raise ArgumentError.new("#{name} required")
    end
  end
end
