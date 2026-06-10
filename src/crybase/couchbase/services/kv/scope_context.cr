class CryBase::CouchBase::Services::KV::ScopeContext(Target)
  getter target : Target
  getter scope : String

  def initialize(
    @target : Target,
    *,
    @scope : String = Constants::DEFAULT_SCOPE,
  )
    raise ArgumentError.new("kv scope required") if @scope.empty?
  end

  def collection(name : String = Constants::DEFAULT_COLLECTION) : CollectionContext(Target)
    CollectionContext.new(@target, scope: @scope, collection: name)
  end
end
