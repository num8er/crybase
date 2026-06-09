require "../structs"

module CryBaseExamples
  def self.query_context : CryBase::CouchBase::Query::QueryContext
    CryBase::CouchBase::Query::QueryContext.new(BUCKET, QUERY_SCOPE, QUERY_NAMESPACE)
  end
end
