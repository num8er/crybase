struct CryBase::CouchBase::Services::Query::PreparedStatement
  getter statement : String
  getter name : String
  getter encoded_plan : String?
  getter raw : JSON::Any

  def initialize(
    @statement : String,
    @name : String,
    @encoded_plan : String?,
    @raw : JSON::Any,
  )
  end

  def self.from_result(statement : String, result : Result) : PreparedStatement
    row = result.rows.first? || raise ArgumentError.new("prepare response did not include a prepared statement")
    name = row["name"]?.try(&.as_s?)
    name ||= result.raw["prepared"]?.try(&.as_s?)
    raise ArgumentError.new("prepare response did not include a prepared statement name") unless name

    new(
      statement,
      name,
      row["encoded_plan"]?.try(&.as_s?),
      row,
    )
  end
end
