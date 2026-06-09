require "../structs"
require "./n1ql_identifier"

module CryBaseExamples
  def self.n1ql_bucket : String
    n1ql_identifier(BUCKET)
  end
end
