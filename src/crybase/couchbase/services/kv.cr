# Implementation of the Couchbase KV (Data) service over Couchbase's
# memcached binary protocol, using plaintext or TLS sockets according to
# the endpoint or connection string.
#
# The main public entry points are `KV::Client.from_string` for one
# authenticated connection, `KV::Pool.from_string` for a fixed-size pool,
# and `KV::Cluster.from_string` for seed failover across multiple KV hosts.
# They accept connection strings with credentials, bucket, explicit KV port,
# and TLS query options:
#
# ```
# cluster = CryBase::CouchBase::KV::Cluster.from_string(
#   "couchbases://user:pass@node1,node2:11217/default?tls_verify=false"
# )
# cluster.set("hello", "world")
# cluster.get("hello") # => Bytes containing "world"
# cluster.close
# ```
#
# You can still construct an `Endpoint` explicitly or through
# `CryBase::CouchBase::Endpoint.from_string` and pass it to `KV::Client.new`
# or `KV::Pool.new` when credentials and bucket should stay separate from
# the endpoint address.
#
# The namespace is structured as small composable pieces:
#
# * `KV::Constants`     — protocol constants used by packet framing
# * `KV::Request`        — value type describing one outbound packet
# * `KV::RequestBuffer`  — serializes one outbound packet into bytes
# * `KV::RequestWriter`  — mixin: writes and flushes a request buffer
# * `KV::Response`       — value type describing one inbound packet
# * `KV::ResponseReader` — mixin: `read` decodes one packet from a socket
# * `KV::Bucket`         — mixin: SELECT_BUCKET handshake
# * `KV::Serializable`   — typed value codec
# * `KV::Pool`           — fixed-size pool of authenticated clients
# * `KV::Cluster`        — seed-failover client backed by `KV::Pool`
#
# `KV::Client` composes the request/response/bucket mixins, performs
# `HELLO`, `SASL_AUTH(PLAIN)`, and `SELECT_BUCKET`, then exposes document,
# expiry, counter, and typed JSON helper operations.
module CryBase::CouchBase::Services::KV
end

require "digest/crc32"
require "openssl"

require "./kv/constants"
require "./kv/opcode"
require "./kv/status"
require "./kv/vbucket"
require "./kv/expiry"
require "./kv/counter"
require "./kv/serializable"
require "./kv/response"
require "./kv/error"
require "./kv/not_found"
require "./kv/auth_failed"
require "./kv/request"
require "./kv/request_buffer"
require "./kv/request_writer"
require "./kv/response_reader"
require "./kv/bucket"
require "./kv/client"
require "./kv/client_delegator"
require "./kv/pool"
require "./kv/cluster"
