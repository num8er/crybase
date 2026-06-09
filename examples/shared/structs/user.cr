require "json"
require "../constants"

struct CryBaseExamples::Structs::User
  include JSON::Serializable

  getter id : String
  getter type : String
  getter name : String
  getter email : String
  getter? active : Bool

  def initialize(
    @id : String,
    @name : String,
    @email : String,
    @active : Bool,
    @type : String = "User",
  )
  end
end
