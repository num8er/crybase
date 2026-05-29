# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Feature implementation notes under `docs/`: [KV Client](docs/1.FEAT_kv-client.md),
  [KV Client Pool](docs/2.FEAT_kv-client-pool.md),
  [Connection String To Endpoint Conversion](docs/3.FEAT_connection-string-to-endpoint-conversion.md),
  [KV Cluster](docs/4.FEAT_kv-cluster.md), and
  [Query Service](docs/5.FEAT_query-service.md), and
  [Connectivity](docs/6.FEAT_connectivity.md), and
  [Query Topology Discovery](docs/7.FEAT_query-topology-discovery.md).
- `AGENTS.md` project guide with feature-documentation and session-startup
  documentation check rules.
- `CryBase::CouchBase::Query::Client` for authenticated N1QL/SQL++ statements
  over the Couchbase HTTP Query service.
- `CryBase::CouchBase::Query::Cluster` for seed failover across Query service
  endpoints.
- `CryBase::CouchBase::Query::Topology` for parsing Query endpoints from
  Couchbase `nodeServices` payloads.
- `CryBase::CouchBase::Query::TopologyClient` for authenticated Query topology
  loading from Couchbase Management.
- `Query::Cluster#refresh_topology` for explicit Query node topology refresh.
- `CryBase::Connectivity` for shared plaintext TCP and TLS socket construction
  used by service-specific clients.
- `CryBase::Connectivity::HostPort.parse` for strict host-port string parsing.
- `CryBase::Connectivity::SocketConfig` for shared timeout and TLS socket
  options.
- `CryBase::Connectivity::TCPSocket.open(host_port)` for host-port strings
  such as `127.0.0.1:12345`.
- `CryBase::Connectivity::TLSSocket.open(host_port, config)` for TLS sockets
  from host-port strings such as `127.0.0.1:12345`.
- `CryBase::Connectivity.open_socket(host_port, config)` for shared plaintext
  or TLS sockets from host-port strings such as `127.0.0.1:12345`.
- Query result parsing for rows, metadata, warnings, and errors.
- `examples/query_basics.cr` for a readonly parameterized Query service call.

### Changed
- README now links to the feature implementation notes.
- CI now exposes the Couchbase Query service port for integration specs.
- The pre-commit hook now strips trailing whitespace from generated HTML docs
  after `crystal docs`.
- KV and Query clients now reuse the shared connectivity layer for socket and
  TLS setup.
- `Query::Cluster.from_string` now discovers Query nodes from Couchbase
  topology by default and keeps static Query seeds as fallback.
- CHANGELOG now records the `v0.0.2` release contents from the git tag range.

## [0.0.2] - 2026-05-22

### Added
- TLS socket support for `KV::Client` and `KV::Pool`, including configurable
  certificate verification, hostname override, and custom OpenSSL client
  context support.
- `CryBase::CouchBase::Services::KV::Cluster`, a seed-failover KV client backed
  by one active `KV::Pool`.
- `Endpoint.from_string`, plus `KV::Client.from_string`, `KV::Pool.from_string`,
  and `KV::Cluster.from_string` helpers for building KV connections from
  Couchbase connection strings, including
  `user:pass@host/bucket?tls_verify=...` parsing.
- Couchbase integration helper support for TLS KV endpoints and alternate
  host ports through `COUCHBASE_TLS`, `COUCHBASE_TLS_VERIFY`,
  `COUCHBASE_KV_PORT`, and `COUCHBASE_MANAGEMENT_PORT`.
- `examples/constants.cr`, a shared environment parser and connection string
  helper used by the runnable examples.
- `examples/kv_cluster.cr` for exercising seed-failover KV operations.
- Generated API documentation for `KV::Cluster`, `KV::Constants`, and
  `KV::RequestBuffer`.
- `CODE_OF_CONDUCT.md`.

### Changed
- KV request serialization now lives in `KV::RequestBuffer.make`, with
  `RequestWriter` responsible only for writing and flushing the generated
  buffer.
- KV protocol constants now live under `KV::Constants` instead of directly
  under `KV`.
- README now documents TLS KV usage, connection string helpers, seed failover,
  generated docs, and example environment variables.
- Runnable examples now reuse `examples/constants.cr` instead of repeating
  Couchbase environment parsing and connection string assembly.
- `shard.yml` and `CryBase::VERSION` were bumped to `0.0.2`.

### Removed
- Removed the local `.gitconfig` file from the repository.

## [0.0.1] - 2026-05-05

### Added
- Initial library scaffold (`shard.yml`, source layout, spec suite).
- `CryBase::CouchBase::ConnectionString` parser supporting `couchbase://`,
  `couchbases://`, `http(s)://` schemes, comma-separated seed hosts, and
  explicit ports.
- `CryBase::CouchBase::Service` enum covering Data (KV), Query, Search,
  Analytics, Index, Eventing, Views, and Management — with plaintext and TLS
  default ports.
- `CryBase::CouchBase::Endpoint` value type describing a single `host:port`
  per service.
- Dummy `CryBase::CouchBase::Client` that enumerates every `(host × service)`
  endpoint and TCP-probes reachability across all interfaces. No Couchbase
  protocol handshake is performed yet.
- Binary-protocol KV client support for authenticated `get`, `set`, and
  `delete` operations against Couchbase Server.
- KV expiration updates through `touch`, plus atomic get-and-touch via
  `get(key, expiry:)`, on both `KV::Client` and `KV::Pool`.
- KV counter operations through `increment` and `decrement` on both
  `KV::Client` and `KV::Pool`.
- Couchbase vbucket hashing for document operations so KV writes are visible
  through Couchbase management and dashboard document lookup.
- `CryBase::CouchBase::Services::KV::Pool`, a fixed-size pool of authenticated
  KV clients with a default size of 10 connections.
- Typed `set`/`get_as(key, Type)` helpers for `JSON::Serializable` KV values on
  both `KV::Client` and `KV::Pool`.
- Real Couchbase integration specs and a GitHub Actions job that boots
  `couchbase:community-7.6.0`, initializes a bucket, and verifies KV behavior
  against a live server.
- Generated API documentation under `docs/`, plus a pre-commit hook step that
  refreshes it with deterministic project metadata.

### Changed
- `KV::Request` and `KV::Response` are now Crystal `record` value types.
- `KV::Response#success?` is defined by reopening the generated response
  struct after the `record` declaration.
- `KV::Pool` now generates its pooled client forwarding methods through an
  internal `ClientDelegator` macro while preserving the same public API.

[Unreleased]: https://github.com/shardscry/crybase/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/shardscry/crybase/releases/tag/v0.0.2
[0.0.1]: https://github.com/shardscry/crybase/releases/tag/v0.0.1
