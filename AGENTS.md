# CryBase Project Guide

## Overview

CryBase is a Crystal language client library for Couchbase. Current status: **early, but past the TCP-probe-only scaffold**. The cluster-level `CryBase::CouchBase::Client` expands Couchbase connection strings into service endpoints and TCP-probes them. The service-specific KV client speaks the Couchbase binary protocol over plaintext or TLS sockets: `HELLO`, SASL PLAIN auth, `SELECT_BUCKET`, document `get`/`set`/`delete`/`touch`, get-and-touch, counters, typed value helpers, fixed-size `KV::Pool`, and seed-failover `KV::Cluster`. The Query service client speaks N1QL/SQL++ over HTTP/HTTPS with `Query::Client` and seed-failover `Query::Cluster`. Search, Analytics, Index, Eventing, Views, and Management protocol clients are not implemented yet.

## Repository Structure

```
crybase/
├── src/
│   ├── crybase.cr              # Main entry point
│   └── crybase/
│       ├── version.cr          # Library version
│       ├── connectivity.cr     # Shared connectivity namespace entry point
│       ├── connectivity/
│       │   ├── host_port.cr    # Strict host:port parser and value object
│       │   ├── socket_config.cr  # Shared socket timeout and TLS options
│       │   ├── tcp_socket.cr   # Plain TCP socket construction
│       │   └── tls_socket.cr   # TLS socket wrapping and context setup
│       ├── couchbase.cr        # Namespace module
│       ├── couchbase/
│       │   ├── client.cr       # Cluster endpoint enumerator and TCP probe client
│       │   ├── service.cr      # Service enum (KV, Query, etc.)
│       │   ├── endpoint.cr     # Endpoint struct
│       │   ├── connection_string.cr  # Connection string parser
│       │   ├── services.cr     # Service-specific protocol namespace
│       │   └── services/
│       │       ├── kv.cr       # KV protocol namespace
│       │       └── kv/
│       │           ├── client.cr       # Authenticated KV protocol client
│       │           ├── pool.cr         # Fixed-size KV client pool
│       │           ├── cluster.cr      # Seed-failover KV pool wrapper
│       │           ├── constants.cr    # KV protocol constants
│       │           ├── request*.cr     # KV request value/framing helpers
│       │           └── response*.cr    # KV response value/framing helpers
│       │       ├── query.cr            # Query service namespace
│       │       └── query/
│       │           ├── client.cr       # Authenticated N1QL HTTP client
│       │           ├── cluster.cr      # Seed-failover Query wrapper
│       │           └── result/error helpers
├── spec/
│   ├── spec_helper.cr          # Test setup
│   └── crybase/
│       ├── couchbase/
│       │   ├── client_spec.cr
│       │   ├── service_spec.cr
│       │   ├── connection_string_spec.cr
│       │   └── services/
│       │       └── kv/         # KV protocol specs
├── spec/integration/
│   └── couchbase_kv_spec.cr    # Real Couchbase KV integration specs
├── examples/                   # Cluster probe and KV examples
│   └── constants.cr            # Shared example env parsing and connection helpers
├── shard.yml                   # Crystal dependency manifest
├── README.md
└── CONTRIBUTING.md
```

## Key Concepts

### Services & Ports

| Service         | Plaintext | TLS    |
|-----------------|-----------|--------|
| Data (KV)       | 11210     | 11207  |
| Query (N1QL)    | 8093      | 18093  |
| Search (FTS)    | 8094      | 18094  |
| Analytics       | 8095      | 18095  |
| Index           | 9102      | 19102  |
| Eventing        | 8096      | 18096  |
| Views           | 8092      | 18092  |
| Management      | 8091      | 18091  |

### Connection String Formats
- `couchbase://host[,host2][:port]` - Plaintext
- `couchbases://host[,host2][:port]` - TLS
- `couchbase://user:pass@host[:port]/bucket?params` - KV credentials/options
- `http(s)://host[:port]` - Management URL

## Development

```sh
crystal spec          # run tests
crystal tool format   # format code
```

## Project Conventions

1. **One flat module per file** - `module CryBase::CouchBase`, not nested blocks
2. **Folder mirrors namespace** - `src/crybase/couchbase/client.cr` for `CryBase::CouchBase::Client`
3. **Use private aliases** - `private alias Client = CryBase::CouchBase::Client`
4. **No comments unless necessary** - only explain non-obvious why, not what
5. **Conventional Commits** - `feat(client): ...`, `fix(connection_string): ...`
6. **Examples share env setup** - runnable examples should require `./constants` instead of reading Couchbase env vars directly
7. **Do not do anything without providing plan** - after reading prompt, make plan of actions and show me before starting any work
8. **Feature docs for implemented features** - for every feature implementation, create `docs/$N.FEAT_$FEATURENAME.md` where `$N` is the next sequence number and `$FEATURENAME` is the slugified feature title. First line must be the title, and the file must include Description, Implementation, and Files affected sections.
9. **Session startup docs check** - when starting a session, check `README.md`, `CHANGELOG.md`, and `docs/*.FEAT_*.md` before making changes so current features, limitations, and release notes are understood.

## Current Limitations

- Cluster-level `CryBase::CouchBase::Client#connect` validates TCP reachability only; protocol handshakes live in service-specific clients.
- Cluster config loading and node/vbucket map routing are not implemented; `KV::Cluster` is seed failover only and keeps one active `KV::Pool`.
- Query support is HTTP endpoint execution plus seed failover only; cluster config loading, prepared statement management, and query-node topology discovery are not implemented yet.
- Search, Analytics, Index, Eventing, Views, and Management protocol clients are not implemented yet.
- Retry/reconnect, durability, observe, CAS helpers, scopes, and collections are not implemented.
- Connection string parsing treats HTTP(S) as Management-only URLs.
