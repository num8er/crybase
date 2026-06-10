require "../shared/methods"

private alias Examples = CryBaseExamples

kv = Examples.open_kv_client

key = "crybase:expiration"

kv.set(key, "short lived", expiry: 2_u32)
puts "SET    #{key} with expiry=2s"

sleep 1.second
kv.touch(key, 10_u32)
puts "TOUCH  #{key} with expiry=10s"

sleep 2.seconds
puts "GET    #{key} => #{String.new(kv.get(key))}"

kv.set(key, "get and touch", expiry: 2_u32)
puts "SET    #{key} with expiry=2s"

sleep 1.second
puts "GAT    #{key} => #{String.new(kv.get(key, expiry: 10_u32))}"

sleep 2.seconds
puts "GET    #{key} => #{String.new(kv.get(key))}"

kv.delete(key)
puts "DELETE #{key}"

kv.close
