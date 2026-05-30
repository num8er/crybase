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

  def self.from_stream(io : IO, &) : Result
    request_id = nil
    client_context_id = nil
    status = nil
    signature = nil
    warnings = [] of Issue
    errors = [] of Issue
    metrics = nil
    profile = nil
    raw = {} of String => JSON::Any
    pull = JSON::PullParser.new(io)

    pull.read_object do |key|
      case key
      when "results"
        pull.read_array do
          yield JSON::Any.new(pull)
        end
        raw[key] = JSON::Any.new([] of JSON::Any)
      else
        value = JSON::Any.new(pull)
        raw[key] = value
        case key
        when "requestID"
          request_id = value.as_s?
        when "clientContextID"
          client_context_id = value.as_s?
        when "status"
          status = value.as_s?
        when "signature"
          signature = value
        when "warnings"
          warnings = issues(value)
        when "errors"
          errors = issues(value)
        when "metrics"
          metrics = value
        when "profile"
          profile = value
        end
      end
    end

    new(
      request_id,
      client_context_id,
      status,
      signature,
      [] of JSON::Any,
      warnings,
      errors,
      metrics,
      profile,
      JSON::Any.new(raw),
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

  def each_row(& : JSON::Any ->) : Nil
    rows.each { |row| yield row }
  end

  def each_row_as(type : T.class, & : T ->) : Nil forall T
    rows.each { |row| yield T.from_json(row.to_json) }
  end

  def issue_code?(code : Int32 | Int64) : Bool
    errors.any? { |issue| issue.code == code.to_i64 }
  end

  def prepared_statement_missing? : Bool
    issue_code?(4040)
  end

  private def self.issues(value : JSON::Any?) : Array(Issue)
    return [] of Issue unless value

    value.as_a?.try(&.map { |issue| Issue.from_json(issue) }) || [] of Issue
  end
end
