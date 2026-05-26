struct CryBase::CouchBase::Services::Query::Result
  getter request_id : String?
  getter client_context_id : String?
  getter status : String?
  getter signature : JSON::Any?
  getter rows : Array(JSON::Any)
  getter warnings : Array(Issue)
  getter errors : Array(Issue)
  getter metrics : JSON::Any?
  getter profile : JSON::Any?
  getter raw : JSON::Any

  def initialize(
    @request_id : String?,
    @client_context_id : String?,
    @status : String?,
    @signature : JSON::Any?,
    @rows : Array(JSON::Any),
    @warnings : Array(Issue),
    @errors : Array(Issue),
    @metrics : JSON::Any?,
    @profile : JSON::Any?,
    @raw : JSON::Any,
  )
  end

  def self.from_body(body : String) : Result
    json = JSON.parse(body)

    new(
      json["requestID"]?.try(&.as_s?),
      json["clientContextID"]?.try(&.as_s?),
      json["status"]?.try(&.as_s?),
      json["signature"]?,
      json["results"]?.try(&.as_a?) || [] of JSON::Any,
      issues(json["warnings"]?),
      issues(json["errors"]?),
      json["metrics"]?,
      json["profile"]?,
      json,
    )
  end

  def success? : Bool
    !error?
  end

  def error? : Bool
    return true unless errors.empty?

    case status.try(&.downcase)
    when "errors", "fatal", "timeout" then true
    else                                   false
    end
  end

  def rows_as(type : T.class) : Array(T) forall T
    rows.map { |row| T.from_json(row.to_json) }
  end

  private def self.issues(value : JSON::Any?) : Array(Issue)
    return [] of Issue unless value

    value.as_a?.try(&.map { |issue| Issue.from_json(issue) }) || [] of Issue
  end
end
