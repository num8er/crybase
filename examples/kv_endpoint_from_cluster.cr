# Combine cluster-level discovery with the KV protocol client:
# probe the cluster for reachable endpoints, pick the first KV one,
# and store/read a typed JSON value against it.
#
# Reads Couchbase settings from `examples/constants.cr`.
#
#   crystal run examples/kv_endpoint_from_cluster.cr
require "json"
require "./constants"

struct Profile
  include JSON::Serializable

  property name : String
  property score : Int32

  def initialize(@name : String, @score : Int32)
  end
end

cluster = CryBase::CouchBase::Client.new(CryBaseExamples.cluster_connection_string)
reachable = cluster.connect

kv_endpoints = reachable.select { |e| e.service == CryBase::CouchBase::Service::KV }
abort "no reachable KV endpoints on #{CryBaseExamples::HOST}" if kv_endpoints.empty?

endpoint = kv_endpoints.first
puts "Using KV endpoint: #{endpoint}"

kv = CryBase::CouchBase::Services::KV::Client.from_string(CryBaseExamples.kv_connection_string(endpoint))

kv.set("crybase:demo", Profile.new("ada", 42))
puts "stored crybase:demo"
profile = kv.get_as("crybase:demo", Profile)
puts "loaded: #{profile.name} scored #{profile.score}"
# kv.delete("crybase:demo")

kv.close
cluster.close
