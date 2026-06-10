require "../shared/methods"

private alias Examples = CryBaseExamples
private alias Profile = CryBaseExamples::Structs::Profile

kv = Examples.open_kv_client

cas = kv.set("crybase:hello", "world")
puts "SET    crybase:hello => CAS=#{cas}"

value = kv.get("crybase:hello")
puts "GET    crybase:hello => #{String.new(value)}"

kv.set("crybase:profile", Profile.new("ada", 42))
profile = kv.get_as("crybase:profile", Profile)
puts "GET    crybase:profile => #{profile.name} scored #{profile.score}"

context = kv.collection(Examples::COLLECTION)
context.set("crybase:context", "current scope collection")
puts "GET    crybase:context => #{String.new(context.get("crybase:context"))}"

# kv.delete("crybase:hello")
# kv.delete("crybase:profile")
# kv.delete("crybase:context")
# puts "DELETE crybase:hello"

kv.close
