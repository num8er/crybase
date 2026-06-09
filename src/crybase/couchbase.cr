# Couchbase Server adapter for CryBase.
#
# Maps the cluster-wide concepts — connection strings, services (KV/Query/…),
# endpoints, and a multi-service client — onto the abstract types declared
# in `CryBase::Interfaces`.
#
# ```
# require "crybase"
#
# client = CryBase::CouchBase::Client.connect("couchbase://node1,node2")
# kv_endpoint = client.endpoints_for(CryBase::CouchBase::Service::KV).first
# client.close
# ```
#
# For protocol-level work against a specific service, see
# `CryBase::CouchBase::Services` (e.g. `Services::KV::Client`).
module CryBase::CouchBase
end

require "./couchbase/service"
require "./couchbase/endpoint"
require "./couchbase/connection_string"
require "./couchbase/policies"
require "./couchbase/services"
require "./couchbase/client"

module CryBase::CouchBase
  alias RetryPolicy = Policies::RetryPolicy
  alias KV = Services::KV
  alias Query = Services::Query
end
