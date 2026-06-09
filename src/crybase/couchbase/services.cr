# Namespace for protocol-level implementations of individual Couchbase
# services. The cluster-level `CryBase::CouchBase::Client` only validates
# TCP reachability; types under `Services` speak each service's actual
# wire protocol.
#
# Currently implemented:
# * `Services::KV` — memcached binary protocol against the KV service
# * `Services::Query` — N1QL/SQL++ over the HTTP Query service
#
# ```
# require "crybase"
#
# CryBase::CouchBase::Services.list.size # => 8
#
# endpoint = CryBase::CouchBase::Endpoint.new(
#   "node1", 11210, CryBase::CouchBase::Service::KV, false
# )
# kv = CryBase::CouchBase::Services::KV::Client.new(
#   endpoint, "user", "pass", "default"
# )
# ```
module CryBase::CouchBase::Services
  # Returns every member of the `CryBase::CouchBase::Service` enum, in
  # the canonical order used when building the per-host endpoint matrix.
  #
  # ```
  # CryBase::CouchBase::Services.list
  # # => [Service::KV, Service::Query, Service::Search, Service::Analytics,
  # #     Service::Index, Service::Eventing, Service::Views, Service::Management]
  # ```
  def self.list : Array(Service)
    [
      Service::KV,
      Service::Query,
      Service::Search,
      Service::Analytics,
      Service::Index,
      Service::Eventing,
      Service::Views,
      Service::Management,
    ]
  end
end

require "./services/kv"
require "./services/query"
