require "../structs"
require "./n1ql_identifier"

module CryBaseExamples
  def self.n1ql_collection : String
    n1ql_identifier(QUERY_COLLECTION)
  end
end
