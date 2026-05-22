# Seed-failover KV operations — connect with multiple seed hosts, store a
# document, and read it back through KV::Cluster.
#
# Reads Couchbase settings from `examples/constants.cr`.
#
#   crystal run examples/kv_cluster.cr
require "./constants"

cluster = CryBase::CouchBase::Services::KV::Cluster.from_string(CryBaseExamples.kv_cluster_connection_string, size: 2)

key = "crybase:cluster"
cluster.set(key, "seed-failover")
puts "SET #{key}"
puts "GET #{key} => #{String.new(cluster.get(key))}"

cluster.delete(key)
puts "DELETE #{key}"

cluster.close
