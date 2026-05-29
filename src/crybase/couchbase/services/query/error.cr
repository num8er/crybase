class CryBase::CouchBase::Services::Query::Error < Exception
  getter status_code : Int32
  getter result : Result

  def initialize(@status_code : Int32, @result : Result)
    super(message_for(status_code, result))
  end

  def retryable? : Bool
    status_code >= 500
  end

  def prepared_statement_missing? : Bool
    result.prepared_statement_missing?
  end

  private def message_for(status_code : Int32, result : Result) : String
    detail = result.errors.first?.try do |issue|
      issue.code ? "#{issue.code}: #{issue.message}" : issue.message
    end

    detail || "Query request failed with HTTP #{status_code}"
  end
end
