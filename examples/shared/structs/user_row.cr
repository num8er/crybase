require "json"
require "../constants"

struct CryBaseExamples::Structs::UserRow
  include JSON::Serializable

  getter doc_key : String
  getter id : String
  getter type : String
  getter name : String
  getter email : String
  getter? active : Bool
end
