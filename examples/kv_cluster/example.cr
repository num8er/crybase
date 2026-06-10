require "../shared/methods"

private alias Examples = CryBaseExamples
private alias KVCluster = CryBase::CouchBase::KV::Cluster

cluster = KVCluster.from_string(Examples.kv_cluster_connection_string, size: 2)
cluster.scope = Examples::SCOPE
cluster.collection = Examples::COLLECTION

key = "crybase:cluster"
cluster.set(key, "seed-failover")
puts "SET #{key}"
puts "GET #{key} => #{String.new(cluster.get(key))}"

current = cluster.collection(Examples::COLLECTION)
current.set("#{key}:context", "current scope collection")
puts "GET #{key}:context => #{String.new(current.get("#{key}:context"))}"

cluster.delete(key)
current.delete("#{key}:context")
puts "DELETE #{key}"

cluster.close
