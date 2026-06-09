require "../shared/methods"

private alias CouchbaseClient = CryBase::CouchBase::Client
private alias Examples = CryBaseExamples

client = CouchbaseClient.new(Examples.cluster_connection_string)
puts "Probing #{client.connection_string.hosts.join(", ")} (#{client.endpoints.size} endpoints total)..."

reachable = client.connect
puts "Reachable:"
reachable.each { |endpoint| puts "  - #{endpoint}" }

client.close
