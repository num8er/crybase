module CryBase::CouchBase::Services::Query
  class Client
    DEFAULT_CONNECT_TIMEOUT = 5.seconds
    DEFAULT_READ_TIMEOUT    = 30.seconds
    DEFAULT_WRITE_TIMEOUT   = 5.seconds
    PATH                    = "/query/service"

    getter endpoint : Endpoint

    @closed : Bool
    @http_client : HTTP::Client?
    @mutex : Mutex
    @prepared_statements : Hash(String, PreparedStatement)

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
      @http_client = nil
      @mutex = Mutex.new
      @prepared_statements = {} of String => PreparedStatement
    end

    # Executes a N1QL/SQL++ statement against this Query endpoint.
    #
    # `readonly: true` sends the Couchbase Query `readonly=true` request option.
    # Use it for `SELECT` and other non-mutating statements; leave it unset for
    # `INSERT`, `UPDATE`, `UPSERT`, `DELETE`, and other mutations.
    #
    # `adhoc: true` is the default and sends the statement directly.
    # `adhoc: false` prepares the statement, caches the prepared plan for the
    # same statement/options, and executes by prepared name. Missing prepared
    # plans are cleared and prepared once again.
    #
    # `retry_policy:` is a per-query policy value. It defaults to
    # `CryBase::CouchBase::RetryPolicy.no_retry`; retry execution is not implemented yet.
    def query(
      statement : String,
      *positional_args,
      named_args = NamedTuple.new,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      query_context : QueryContext | String | Nil = nil,
      bucket : String? = nil,
      scope : String? = nil,
      namespace : String? = nil,
      options = NamedTuple.new,
      retry_policy : CryBase::CouchBase::RetryPolicy = CryBase::CouchBase::RetryPolicy.no_retry,
      adhoc : Bool = true,
      raise_on_error : Bool = true,
    ) : Result
      @mutex.synchronize do
        raise_closed! if @closed

        if adhoc
          return execute(
            self.class.form(
              statement,
              positional_args,
              named_args,
              readonly,
              scan_consistency,
              client_context_id,
              timeout,
              query_context,
              bucket,
              scope,
              namespace,
              options,
            ),
            raise_on_error,
            retry_policy,
          )
        end

        execute_cached_statement(
          statement,
          positional_args,
          named_args,
          readonly,
          scan_consistency,
          client_context_id,
          timeout,
          query_context,
          bucket,
          scope,
          namespace,
          options,
          retry_policy,
          raise_on_error,
        )
      end
    end

    def prepare(
      statement : String,
      name : String? = nil,
      *,
      force : Bool = false,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      query_context : QueryContext | String | Nil = nil,
      bucket : String? = nil,
      scope : String? = nil,
      namespace : String? = nil,
      options = NamedTuple.new,
    ) : PreparedStatement
      @mutex.synchronize do
        raise_closed! if @closed
        prepare_locked(
          statement,
          name,
          force,
          readonly,
          scan_consistency,
          client_context_id,
          timeout,
          query_context,
          bucket,
          scope,
          namespace,
          options,
        )
      end
    end

    def execute_prepared(
      prepared : PreparedStatement,
      *positional_args,
      named_args = NamedTuple.new,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      query_context : QueryContext | String | Nil = nil,
      bucket : String? = nil,
      scope : String? = nil,
      namespace : String? = nil,
      options = NamedTuple.new,
      raise_on_error : Bool = true,
    ) : Result
      @mutex.synchronize do
        raise_closed! if @closed
        execute_prepared_with_retry(
          prepared,
          positional_args,
          named_args,
          readonly,
          scan_consistency,
          client_context_id,
          timeout,
          query_context,
          bucket,
          scope,
          namespace,
          options,
          raise_on_error,
        )
      end
    end

    def execute_prepared(
      prepared : String,
      *positional_args,
      named_args = NamedTuple.new,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      query_context : QueryContext | String | Nil = nil,
      bucket : String? = nil,
      scope : String? = nil,
      namespace : String? = nil,
      options = NamedTuple.new,
      raise_on_error : Bool = true,
    ) : Result
      @mutex.synchronize do
        raise_closed! if @closed
        execute_prepared_locked(
          prepared,
          positional_args,
          named_args,
          readonly,
          scan_consistency,
          client_context_id,
          timeout,
          query_context,
          bucket,
          scope,
          namespace,
          options,
          raise_on_error,
        )
      end
    end

    def query_as(
      type : T.class,
      statement : String,
      *positional_args,
      named_args = NamedTuple.new,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      query_context : QueryContext | String | Nil = nil,
      bucket : String? = nil,
      scope : String? = nil,
      namespace : String? = nil,
      options = NamedTuple.new,
      adhoc : Bool = true,
      raise_on_error : Bool = true,
    ) : Array(T) forall T
      query(
        statement,
        *positional_args,
        named_args: named_args,
        readonly: readonly,
        scan_consistency: scan_consistency,
        client_context_id: client_context_id,
        timeout: timeout,
        query_context: query_context,
        bucket: bucket,
        scope: scope,
        namespace: namespace,
        options: options,
        adhoc: adhoc,
        raise_on_error: raise_on_error,
      ).rows_as(T)
    end

    def query_each(
      statement : String,
      *positional_args,
      named_args = NamedTuple.new,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      query_context : QueryContext | String | Nil = nil,
      bucket : String? = nil,
      scope : String? = nil,
      namespace : String? = nil,
      options = NamedTuple.new,
      raise_on_error : Bool = true,
      & : JSON::Any ->
    ) : Result
      @mutex.synchronize do
        raise_closed! if @closed

        execute_stream(
          self.class.form(
            statement,
            positional_args,
            named_args,
            readonly,
            scan_consistency,
            client_context_id,
            timeout,
            query_context,
            bucket,
            scope,
            namespace,
            options,
          ),
          raise_on_error,
        ) { |row| yield row }
      end
    end

    def query_each_as(
      type : T.class,
      statement : String,
      *positional_args,
      named_args = NamedTuple.new,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      query_context : QueryContext | String | Nil = nil,
      bucket : String? = nil,
      scope : String? = nil,
      namespace : String? = nil,
      options = NamedTuple.new,
      raise_on_error : Bool = true,
      & : T ->
    ) : Result forall T
      query_each(
        statement,
        *positional_args,
        named_args: named_args,
        readonly: readonly,
        scan_consistency: scan_consistency,
        client_context_id: client_context_id,
        timeout: timeout,
        query_context: query_context,
        bucket: bucket,
        scope: scope,
        namespace: namespace,
        options: options,
        raise_on_error: raise_on_error,
      ) do |row|
        yield T.from_json(row.to_json)
      end
    end

    def query_cursor(
      statement : String,
      *positional_args,
      named_args = NamedTuple.new,
      readonly : Bool? = nil,
      scan_consistency : ScanConsistency | String | Nil = nil,
      client_context_id : String? = nil,
      timeout : Time::Span? = nil,
      query_context : QueryContext | String | Nil = nil,
      bucket : String? = nil,
      scope : String? = nil,
      namespace : String? = nil,
      options = NamedTuple.new,
      raise_on_error : Bool = true,
    ) : Cursor
      Cursor.new do |emit|
        query_each(
          statement,
          *positional_args,
          named_args: named_args,
          readonly: readonly,
          scan_consistency: scan_consistency,
          client_context_id: client_context_id,
          timeout: timeout,
          query_context: query_context,
          bucket: bucket,
          scope: scope,
          namespace: namespace,
          options: options,
          raise_on_error: raise_on_error,
        ) { |row| emit.call(row) }
      end
    end

    def clear_prepared_cache : Nil
      @mutex.synchronize { @prepared_statements.clear }
    end

    def close : Nil
      @mutex.synchronize do
        @closed = true
        close_http_client
      end
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
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
      options,
    ) : String
      URI::Params.build do |form|
        form.add("statement", statement)
        add_common_form_params(
          form,
          positional_args,
          named_args,
          readonly,
          scan_consistency,
          client_context_id,
          timeout,
          query_context,
          bucket,
          scope,
          namespace,
          options,
        )
      end
    end

    def self.prepared_form(
      prepared : String,
      positional_args,
      named_args,
      readonly : Bool?,
      scan_consistency : ScanConsistency | String | Nil,
      client_context_id : String?,
      timeout : Time::Span?,
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
      options,
    ) : String
      URI::Params.build do |form|
        form.add("prepared", prepared)
        add_common_form_params(
          form,
          positional_args,
          named_args,
          readonly,
          scan_consistency,
          client_context_id,
          timeout,
          query_context,
          bucket,
          scope,
          namespace,
          options,
        )
      end
    end

    def self.prepare_statement(
      statement : String,
      name : String? = nil,
      force : Bool = false,
    ) : String
      parts = ["PREPARE"]
      parts << "FORCE" if force
      if prepared_name = name
        parts << prepared_name
        parts << "AS"
      end
      parts << statement
      parts.join(' ')
    end

    def self.prepared_cache_key(
      statement : String,
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
      options,
    ) : String
      URI::Params.build do |params|
        params.add("statement", statement)
        if context = query_context_param(query_context, bucket, scope, namespace)
          params.add("query_context", context)
          add_options(params, options, skip_query_context: true)
        else
          add_options(params, options)
        end
      end
    end

    private def execute_cached_statement(
      statement,
      positional_args,
      named_args,
      readonly,
      scan_consistency,
      client_context_id,
      timeout,
      query_context,
      bucket,
      scope,
      namespace,
      options,
      retry_policy,
      raise_on_error,
    ) : Result
      cache_key = self.class.prepared_cache_key(statement, query_context, bucket, scope, namespace, options)
      prepared = @prepared_statements[cache_key]? || prepare_locked(
        statement,
        nil,
        false,
        readonly,
        scan_consistency,
        nil,
        timeout,
        query_context,
        bucket,
        scope,
        namespace,
        options,
        cache_key,
      )

      execute_prepared_with_retry(
        prepared,
        positional_args,
        named_args,
        readonly,
        scan_consistency,
        client_context_id,
        timeout,
        query_context,
        bucket,
        scope,
        namespace,
        options,
        raise_on_error,
        retry_policy,
        cache_key,
      )
    end

    private def execute(
      form : String,
      raise_on_error : Bool,
      _retry_policy : CryBase::CouchBase::RetryPolicy = CryBase::CouchBase::RetryPolicy.no_retry,
    ) : Result
      attempts = 0

      loop do
        attempts += 1

        begin
          response = http_client.post(PATH, request_headers, form: form)
          result = Result.from_body(response.body)
          raise Error.new(response.status_code, result) if raise_on_error && (!response.success? || result.error?)

          return result
        rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error
          close_http_client
          raise ex if attempts > 1
        rescue ex : Exception
          if reconnect_error?(ex) && attempts == 1
            close_http_client
          else
            raise ex
          end
        end
      end
    end

    private def execute_stream(form : String, raise_on_error : Bool, &) : Result
      attempts = 0

      loop do
        attempts += 1

        begin
          result = nil
          status_code = 0
          success = false

          http_client.post(PATH, request_headers, form: form) do |response|
            status_code = response.status_code
            success = response.success?
            result = Result.from_stream(response.body_io) { |row| yield row }
          end

          parsed = result || raise IO::Error.new("empty Query response")
          raise Error.new(status_code, parsed) if raise_on_error && (!success || parsed.error?)

          return parsed
        rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error
          close_http_client
          raise ex if attempts > 1
        rescue ex : Exception
          if reconnect_error?(ex) && attempts == 1
            close_http_client
          else
            raise ex
          end
        end
      end
    end

    private def prepare_locked(
      statement : String,
      name : String?,
      force : Bool,
      readonly : Bool?,
      scan_consistency : ScanConsistency | String | Nil,
      client_context_id : String?,
      timeout : Time::Span?,
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
      options,
      cache_key : String? = nil,
    ) : PreparedStatement
      result = execute(
        self.class.form(
          self.class.prepare_statement(statement, name, force),
          Tuple.new,
          NamedTuple.new,
          readonly,
          scan_consistency,
          client_context_id,
          timeout,
          query_context,
          bucket,
          scope,
          namespace,
          options,
        ),
        true,
      )
      prepared = PreparedStatement.from_result(statement, result)
      @prepared_statements[cache_key] = prepared if cache_key
      prepared
    end

    private def execute_prepared_with_retry(
      prepared : PreparedStatement,
      positional_args,
      named_args,
      readonly : Bool?,
      scan_consistency : ScanConsistency | String | Nil,
      client_context_id : String?,
      timeout : Time::Span?,
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
      options,
      raise_on_error : Bool,
      retry_policy : CryBase::CouchBase::RetryPolicy = CryBase::CouchBase::RetryPolicy.no_retry,
      cache_key : String? = nil,
    ) : Result
      result = execute_prepared_retryable(
        prepared,
        positional_args,
        named_args,
        readonly,
        scan_consistency,
        client_context_id,
        timeout,
        query_context,
        bucket,
        scope,
        namespace,
        options,
        raise_on_error,
        retry_policy,
      )
      return result unless result.prepared_statement_missing?

      cache_key.try { |key| @prepared_statements.delete(key) }
      refreshed = prepare_locked(
        prepared.statement,
        nil,
        true,
        readonly,
        scan_consistency,
        nil,
        timeout,
        query_context,
        bucket,
        scope,
        namespace,
        options,
        cache_key,
      )
      execute_prepared_locked(
        refreshed.name,
        positional_args,
        named_args,
        readonly,
        scan_consistency,
        client_context_id,
        timeout,
        query_context,
        bucket,
        scope,
        namespace,
        options,
        raise_on_error,
        retry_policy,
      )
    rescue ex : Error
      raise ex unless ex.prepared_statement_missing?

      cache_key.try { |key| @prepared_statements.delete(key) }
      refreshed = prepare_locked(
        prepared.statement,
        nil,
        true,
        readonly,
        scan_consistency,
        nil,
        timeout,
        query_context,
        bucket,
        scope,
        namespace,
        options,
        cache_key,
      )
      execute_prepared_locked(
        refreshed.name,
        positional_args,
        named_args,
        readonly,
        scan_consistency,
        client_context_id,
        timeout,
        query_context,
        bucket,
        scope,
        namespace,
        options,
        raise_on_error,
        retry_policy,
      )
    end

    private def execute_prepared_retryable(
      prepared : PreparedStatement,
      positional_args,
      named_args,
      readonly : Bool?,
      scan_consistency : ScanConsistency | String | Nil,
      client_context_id : String?,
      timeout : Time::Span?,
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
      options,
      raise_on_error : Bool,
      retry_policy : CryBase::CouchBase::RetryPolicy = CryBase::CouchBase::RetryPolicy.no_retry,
    ) : Result
      execute_prepared_locked(
        prepared.name,
        positional_args,
        named_args,
        readonly,
        scan_consistency,
        client_context_id,
        timeout,
        query_context,
        bucket,
        scope,
        namespace,
        options,
        raise_on_error,
        retry_policy,
      )
    end

    private def execute_prepared_locked(
      prepared : String,
      positional_args,
      named_args,
      readonly : Bool?,
      scan_consistency : ScanConsistency | String | Nil,
      client_context_id : String?,
      timeout : Time::Span?,
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
      options,
      raise_on_error : Bool,
      retry_policy : CryBase::CouchBase::RetryPolicy = CryBase::CouchBase::RetryPolicy.no_retry,
    ) : Result
      execute(
        self.class.prepared_form(
          prepared,
          positional_args,
          named_args,
          readonly,
          scan_consistency,
          client_context_id,
          timeout,
          query_context,
          bucket,
          scope,
          namespace,
          options,
        ),
        raise_on_error,
        retry_policy,
      )
    end

    private def http_client : HTTP::Client
      @http_client ||= open_http_client
    end

    private def open_http_client : HTTP::Client
      io = open_io
      client = HTTP::Client.new(io, @endpoint.host, @endpoint.port)
      client.basic_auth(@username, @password)
      client
    end

    private def close_http_client : Nil
      @http_client.try(&.close)
    ensure
      @http_client = nil
    end

    private def reconnect_error?(error : Exception) : Bool
      error.message == "This HTTP::Client cannot be reconnected"
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
        "Accept" => "application/json",
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

    private def self.add_common_form_params(
      form : URI::Params::Builder,
      positional_args,
      named_args,
      readonly : Bool?,
      scan_consistency : ScanConsistency | String | Nil,
      client_context_id : String?,
      timeout : Time::Span?,
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
      options,
    ) : Nil
      form.add("args", positional_args.to_json) unless positional_args.empty?
      add_named_args(form, named_args)
      form.add("readonly", readonly.to_s) unless readonly.nil?
      form.add("scan_consistency", scan_consistency_param(scan_consistency)) if scan_consistency
      form.add("client_context_id", client_context_id) if client_context_id
      form.add("timeout", "#{timeout.total_milliseconds.to_i64}ms") if timeout
      if context = query_context_param(query_context, bucket, scope, namespace)
        form.add("query_context", context)
        add_options(form, options, skip_query_context: true)
      else
        add_options(form, options)
      end
    end

    private def self.add_options(
      form : URI::Params::Builder,
      options : NamedTuple,
      skip_query_context : Bool = false,
    ) : Nil
      options.each do |name, value|
        next if skip_query_context && name.to_s == "query_context"

        form.add(name.to_s, value.to_s)
      end
    end

    private def self.add_options(
      form : URI::Params::Builder,
      options : Hash,
      skip_query_context : Bool = false,
    ) : Nil
      options.each do |name, value|
        next if skip_query_context && name.to_s == "query_context"

        form.add(name.to_s, value.to_s)
      end
    end

    private def self.query_context_param(
      query_context : QueryContext | String | Nil,
      bucket : String?,
      scope : String?,
      namespace : String?,
    ) : String?
      if query_context
        if bucket || scope || namespace
          raise ArgumentError.new("query_context cannot be combined with bucket, scope, or namespace")
        end

        return query_context.to_s
      end

      return nil unless bucket || scope || namespace

      QueryContext.new(
        bucket || raise(ArgumentError.new("query context bucket required")),
        scope || QueryContext::DEFAULT_SCOPE,
        namespace || QueryContext::DEFAULT_NAMESPACE,
      ).to_s
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
