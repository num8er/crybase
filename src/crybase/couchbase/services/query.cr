require "http/client"
require "json"
require "openssl"

# Implementation of the Couchbase Query service over its HTTP N1QL API.
#
# The main public entry points are `Query::Client.from_string` for one
# configured Query endpoint and `Query::Cluster.from_string` for seed failover
# across multiple Query hosts. Query requests are posted to `/query/service`
# as `application/x-www-form-urlencoded` payloads.
module CryBase::CouchBase::Services::Query
  alias Parameter = Nil | Bool | Int32 | Int64 | Float32 | Float64 | String | JSON::Any
end

require "./query/scan_consistency"
require "./query/issue"
require "./query/result"
require "./query/error"
require "./query/topology"
require "./query/topology_client"
require "./query/client"
require "./query/cluster"
