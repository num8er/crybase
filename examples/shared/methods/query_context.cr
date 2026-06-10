require "../structs"

module CryBaseExamples
  def self.query_context : CryBase::CouchBase::Query::QueryContext
    CryBase::CouchBase::Query::QueryContext.new(
      bucket: BUCKET,
      scope: QUERY_SCOPE,
    )
  end
end
