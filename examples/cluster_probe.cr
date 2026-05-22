# Cluster-level probe — opens a TCP connection to every service
# interface (KV, Query, Search, …) on every host in the connection
# string, prints the reachable subset.
#
# Reads Couchbase settings from `examples/constants.cr`.
#
#   crystal run examples/cluster_probe.cr
require "./constants"

client = CryBase::CouchBase::Client.new(CryBaseExamples.cluster_connection_string)
puts "Probing #{client.connection_string.hosts.join(", ")} (#{client.endpoints.size} endpoints total)..."

reachable = client.connect
puts "Reachable:"
reachable.each { |endpoint| puts "  - #{endpoint}" }

client.close
