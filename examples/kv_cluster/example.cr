require "../shared/methods"

private alias Examples = CryBaseExamples
private alias KVCluster = CryBase::CouchBase::KV::Cluster

cluster = KVCluster.from_string(Examples.kv_cluster_connection_string, size: 2)

key = "crybase:cluster"
cluster.set(key, "seed-failover")
puts "SET #{key}"
puts "GET #{key} => #{String.new(cluster.get(key))}"

cluster.delete(key)
puts "DELETE #{key}"

cluster.close
