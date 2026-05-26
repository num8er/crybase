record CryBase::CouchBase::Services::Query::Issue,
  code : Int64?,
  message : String do
  def self.from_json(value : JSON::Any) : Issue
    hash = value.as_h?
    return new(nil, value.to_json) unless hash

    new(
      hash["code"]?.try(&.as_i64?),
      hash["msg"]?.try(&.as_s?) || hash["message"]?.try(&.as_s?) || value.to_json,
    )
  end
end
