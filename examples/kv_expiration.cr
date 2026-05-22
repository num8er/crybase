# KV expiration operations — set a document with TTL, extend it with
# TOUCH, and fetch while atomically resetting expiry with GET_AND_TOUCH.
#
# Reads Couchbase settings from `examples/constants.cr`.
#
#   crystal run examples/kv_expiration.cr
require "./constants"

kv = CryBase::CouchBase::Services::KV::Client.from_string(CryBaseExamples.kv_connection_string)

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
