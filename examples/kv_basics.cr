# Basic KV operations — connect to one Couchbase KV node, store a
# document, read it back, and store a typed JSON value.
#
# Reads Couchbase settings from `examples/constants.cr`.
#
#   crystal run examples/kv_basics.cr
require "json"
require "./constants"

struct Profile
  include JSON::Serializable

  property name : String
  property score : Int32

  def initialize(@name : String, @score : Int32)
  end
end

kv = CryBase::CouchBase::Services::KV::Client.from_string(CryBaseExamples.kv_connection_string)

cas = kv.set("crybase:hello", "world")
puts "SET    crybase:hello => CAS=#{cas}"

value = kv.get("crybase:hello")
puts "GET    crybase:hello => #{String.new(value)}"

kv.set("crybase:profile", Profile.new("ada", 42))
profile = kv.get_as("crybase:profile", Profile)
puts "GET    crybase:profile => #{profile.name} scored #{profile.score}"

# kv.delete("crybase:hello")
# kv.delete("crybase:profile")
# puts "DELETE crybase:hello"

kv.close
