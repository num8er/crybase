require "../shared/methods"

private alias Examples = CryBaseExamples
private alias KVClient = CryBase::CouchBase::KV::Client
private alias Profile = CryBaseExamples::Structs::Profile

kv = KVClient.from_string(Examples.kv_connection_string)

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
