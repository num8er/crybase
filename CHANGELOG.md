# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Binary-protocol KV client support for authenticated `get`, `set`, and
  `delete` operations against Couchbase Server.
- TLS socket support for `KV::Client` and `KV::Pool`, including configurable
  certificate verification, hostname override, and custom OpenSSL client
  context support.
- KV expiration updates through `touch`, plus atomic get-and-touch via
  `get(key, expiry:)`, on both `KV::Client` and `KV::Pool`.
- KV counter operations through `increment` and `decrement` on both
  `KV::Client` and `KV::Pool`.
- Couchbase vbucket hashing for document operations so KV writes are visible
  through Couchbase management and dashboard document lookup.
- `CryBase::CouchBase::Services::KV::Pool`, a fixed-size pool of authenticated
  KV clients with a default size of 10 connections.
- `CryBase::CouchBase::Services::KV::Cluster`, a seed-failover KV client backed
  by one active `KV::Pool`.
- Typed `set`/`get_as(key, Type)` helpers for `JSON::Serializable` KV values on
  both `KV::Client` and `KV::Pool`.
- Real Couchbase integration specs and a GitHub Actions job that boots
  `couchbase:community-7.6.0`, initializes a bucket, and verifies KV behavior
  against a live server.
- Couchbase integration helper support for TLS KV endpoints and alternate
  host ports through `COUCHBASE_TLS`, `COUCHBASE_TLS_VERIFY`,
  `COUCHBASE_KV_PORT`, and `COUCHBASE_MANAGEMENT_PORT`.
- Generated API documentation under `docs/`, plus a pre-commit hook step that
  refreshes it with deterministic project metadata.
- Feature implementation notes under `docs/`: [KV Client](docs/1.FEAT_kv-client.md),
  [KV Client Pool](docs/2.FEAT_kv-client-pool.md),
  [Connection String To Endpoint Conversion](docs/3.FEAT_connection-string-to-endpoint-conversion.md),
  and [KV Cluster](docs/4.FEAT_kv-cluster.md).
- `Endpoint.from_string`, plus `KV::Client.from_string` and
  `KV::Pool.from_string` helpers for building KV connections from Couchbase
  connection strings, including `user:pass@host/bucket?tls_verify=...`
  parsing.
- `examples/constants.cr`, a shared environment parser and connection string
  helper used by the runnable examples.

### Changed
- `KV::Request` and `KV::Response` are now Crystal `record` value types.
- KV request serialization now lives in `KV::RequestBuffer.make`, with
  `RequestWriter` responsible only for writing and flushing the generated
  buffer.
- KV protocol constants now live under `KV::Constants` instead of directly
  under `KV`.
- `KV::Response#success?` is defined by reopening the generated response
  struct after the `record` declaration.
- `KV::Pool` now generates its pooled client forwarding methods through an
  internal `ClientDelegator` macro while preserving the same public API.
- README now documents public modules, KV usage, connection pooling, generated
  docs, and hook setup.
- Runnable examples now reuse `examples/constants.cr` instead of repeating
  Couchbase environment parsing and connection string assembly.

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

[0.0.1]: https://github.com/shardscry/crybase/releases/tag/v0.0.1
