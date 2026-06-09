struct CryBase::CouchBase::Services::Query::QueryContext
  DEFAULT_NAMESPACE = "default"
  DEFAULT_SCOPE     = "_default"

  getter namespace : String
  getter bucket : String
  getter scope : String

  def initialize(
    @bucket : String,
    @scope : String = DEFAULT_SCOPE,
    @namespace : String = DEFAULT_NAMESPACE,
  )
    raise ArgumentError.new("query context bucket required") if @bucket.empty?
    raise ArgumentError.new("query context scope required") if @scope.empty?
    raise ArgumentError.new("query context namespace required") if @namespace.empty?
  end

  def to_s(io : IO) : Nil
    io << @namespace << ':'
    write_identifier(io, @bucket)
    io << '.'
    write_identifier(io, @scope)
  end

  private def write_identifier(io : IO, value : String) : Nil
    io << '`' << value.gsub("`", "``") << '`'
  end
end
