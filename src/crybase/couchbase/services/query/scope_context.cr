class CryBase::CouchBase::Services::Query::ScopeContext(Target)
  getter target : Target
  getter query_context : QueryContext

  def initialize(
    @target : Target,
    *,
    bucket : String,
    scope : String = QueryContext::DEFAULT_SCOPE,
    namespace : String = QueryContext::DEFAULT_NAMESPACE,
  )
    @query_context = QueryContext.new(
      bucket: bucket,
      scope: scope,
      namespace: namespace,
    )
  end

  def namespace : String
    @query_context.namespace
  end

  def bucket : String
    @query_context.bucket
  end

  def scope : String
    @query_context.scope
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
    retry_policy : CryBase::CouchBase::RetryPolicy = CryBase::CouchBase::RetryPolicy.no_retry,
    adhoc : Bool = true,
    raise_on_error : Bool = true,
  ) : Result
    @target.query(
      statement,
      *positional_args,
      named_args: named_args,
      readonly: readonly,
      scan_consistency: scan_consistency,
      client_context_id: client_context_id,
      timeout: timeout,
      query_context: @query_context,
      options: options,
      retry_policy: retry_policy,
      adhoc: adhoc,
      raise_on_error: raise_on_error,
    )
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
    options = NamedTuple.new,
    adhoc : Bool = true,
    raise_on_error : Bool = true,
  ) : Array(T) forall T
    @target.query_as(
      type,
      statement,
      *positional_args,
      named_args: named_args,
      readonly: readonly,
      scan_consistency: scan_consistency,
      client_context_id: client_context_id,
      timeout: timeout,
      query_context: @query_context,
      options: options,
      adhoc: adhoc,
      raise_on_error: raise_on_error,
    )
  end

  def query_each(
    statement : String,
    *positional_args,
    named_args = NamedTuple.new,
    readonly : Bool? = nil,
    scan_consistency : ScanConsistency | String | Nil = nil,
    client_context_id : String? = nil,
    timeout : Time::Span? = nil,
    options = NamedTuple.new,
    raise_on_error : Bool = true,
    & : JSON::Any ->
  ) : Result
    @target.query_each(
      statement,
      *positional_args,
      named_args: named_args,
      readonly: readonly,
      scan_consistency: scan_consistency,
      client_context_id: client_context_id,
      timeout: timeout,
      query_context: @query_context,
      options: options,
      raise_on_error: raise_on_error,
    ) { |row| yield row }
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
    options = NamedTuple.new,
    raise_on_error : Bool = true,
    & : T ->
  ) : Result forall T
    @target.query_each_as(
      type,
      statement,
      *positional_args,
      named_args: named_args,
      readonly: readonly,
      scan_consistency: scan_consistency,
      client_context_id: client_context_id,
      timeout: timeout,
      query_context: @query_context,
      options: options,
      raise_on_error: raise_on_error,
    ) { |row| yield row }
  end

  def query_cursor(
    statement : String,
    *positional_args,
    named_args = NamedTuple.new,
    readonly : Bool? = nil,
    scan_consistency : ScanConsistency | String | Nil = nil,
    client_context_id : String? = nil,
    timeout : Time::Span? = nil,
    options = NamedTuple.new,
    raise_on_error : Bool = true,
  ) : Cursor
    @target.query_cursor(
      statement,
      *positional_args,
      named_args: named_args,
      readonly: readonly,
      scan_consistency: scan_consistency,
      client_context_id: client_context_id,
      timeout: timeout,
      query_context: @query_context,
      options: options,
      raise_on_error: raise_on_error,
    )
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
    options = NamedTuple.new,
  ) : PreparedStatement
    @target.prepare(
      statement,
      name,
      force: force,
      readonly: readonly,
      scan_consistency: scan_consistency,
      client_context_id: client_context_id,
      timeout: timeout,
      query_context: @query_context,
      options: options,
    )
  end

  def execute_prepared(
    prepared : PreparedStatement,
    *positional_args,
    named_args = NamedTuple.new,
    readonly : Bool? = nil,
    scan_consistency : ScanConsistency | String | Nil = nil,
    client_context_id : String? = nil,
    timeout : Time::Span? = nil,
    options = NamedTuple.new,
    raise_on_error : Bool = true,
  ) : Result
    @target.execute_prepared(
      prepared,
      *positional_args,
      named_args: named_args,
      readonly: readonly,
      scan_consistency: scan_consistency,
      client_context_id: client_context_id,
      timeout: timeout,
      query_context: @query_context,
      options: options,
      raise_on_error: raise_on_error,
    )
  end

  def execute_prepared(
    prepared : String,
    *positional_args,
    named_args = NamedTuple.new,
    readonly : Bool? = nil,
    scan_consistency : ScanConsistency | String | Nil = nil,
    client_context_id : String? = nil,
    timeout : Time::Span? = nil,
    options = NamedTuple.new,
    raise_on_error : Bool = true,
  ) : Result
    @target.execute_prepared(
      prepared,
      *positional_args,
      named_args: named_args,
      readonly: readonly,
      scan_consistency: scan_consistency,
      client_context_id: client_context_id,
      timeout: timeout,
      query_context: @query_context,
      options: options,
      raise_on_error: raise_on_error,
    )
  end
end
