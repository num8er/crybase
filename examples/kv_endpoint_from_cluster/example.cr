require "../shared/methods"

private alias CouchbaseClient = CryBase::CouchBase::Client
private alias Examples = CryBaseExamples
private alias KVClient = CryBase::CouchBase::KV::Client
private alias Profile = CryBaseExamples::Structs::Profile
private alias Service = CryBase::CouchBase::Service

cluster = CouchbaseClient.new(Examples.cluster_connection_string)
reachable = cluster.connect

kv_endpoints = reachable.select { |e| e.service == Service::KV }
abort "no reachable KV endpoints on #{Examples::HOST}" if kv_endpoints.empty?

endpoint = kv_endpoints.first
puts "Using KV endpoint: #{endpoint}"

kv = KVClient.from_string(Examples.kv_connection_string(endpoint))
kv.scope = Examples::SCOPE
kv.collection = Examples::COLLECTION

kv.set("crybase:demo", Profile.new("ada", 42))
puts "stored crybase:demo"
profile = kv.get_as("crybase:demo", Profile)
puts "loaded: #{profile.name} scored #{profile.score}"
# kv.delete("crybase:demo")

kv.close
cluster.close
