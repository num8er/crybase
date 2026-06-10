class CryBase::CouchBase::Services::Query::BucketContext(Target)
  getter target : Target
  getter bucket : String
  getter namespace : String

  def initialize(
    @target : Target,
    *,
    @bucket : String,
    @namespace : String = QueryContext::DEFAULT_NAMESPACE,
  )
    raise ArgumentError.new("query context bucket required") if @bucket.empty?
    raise ArgumentError.new("query context namespace required") if @namespace.empty?
  end

  def scope(name : String = QueryContext::DEFAULT_SCOPE) : ScopeContext(Target)
    ScopeContext.new(@target, bucket: @bucket, scope: name, namespace: @namespace)
  end
end
