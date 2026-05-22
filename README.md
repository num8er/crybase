```text
  ______           ____
 / ____/______  __/ __ )____ _________
/ /   / ___/ / / / __  / __ `/ ___/ _ \
/ /___/ /  / /_/ / /_/ / /_/ (__  )  __/
\____/_/   \__, /_____/\__,_/____/\___/
          /____/
```

# CryBase

[![Crystal](https://img.shields.io/badge/Crystal-1.20%2B-000000?logo=crystal&logoColor=white)](https://crystal-lang.org/)
[![Couchbase](https://img.shields.io/badge/Couchbase-KV%20Client-EA2328?logo=couchbase&logoColor=white)](https://www.couchbase.com/)

Crystal client primitives for Couchbase.

CryBase is still early, but it now has two useful layers:

- A cluster-level client that expands Couchbase connection strings into service
  endpoints and TCP-probes them.
- A KV client that speaks the Couchbase binary protocol over plaintext or TLS
  sockets for authenticated `get`, `set`, `delete`, `touch`, and counter
  operations, plus fixed-size and seed-failover connection pools.

## Status

Implemented:

- Connection string parsing for `couchbase://`, `couchbases://`, and
  `http(s)://`.
- Service and endpoint modeling for KV, Query, Search, Analytics, Index,
  Eventing, Views, and Management.
- Plain TCP reachability probing for cluster service endpoints.
- KV binary protocol handshake: `HELLO`, SASL PLAIN auth, and `SELECT_BUCKET`.
- TLS socket support for KV operations.
- KV document operations: `get`, `set`, `delete`, `touch`, `increment`,
  `decrement`.
- Couchbase vbucket hashing for KV document routing.
- `KV::Pool` with 10 authenticated connections by default.
- `KV::Cluster` seed failover across multiple KV hosts.
- Real Couchbase integration specs in GitHub Actions.

Not implemented yet:

- Cluster config loading and node/vbucket map routing.
- Retry, reconnect, durability, observe, CAS helpers, scopes, or collections.
- Query, Search, Analytics, Index, Eventing, Views, and Management protocols.

## Installation

Add CryBase to `shard.yml`:

```yaml
dependencies:
  crybase:
    github: shardscry/crybase
```

Then install dependencies:

```sh
shards install
```

## Quick Start

### Probe Cluster Endpoints

```crystal
require "crybase"

client = CryBase::CouchBase::Client.new("couchbase://node1,node2")

puts "Cluster nodes:"
client.connection_string.hosts.each do |host|
  puts "  - #{host}"
end

puts "Reachable endpoints:"
client.connect.each do |endpoint|
  puts "  - #{endpoint}"
end

client.close
```

### Use One KV Connection

```crystal
require "crybase"

kv = CryBase::CouchBase::Services::KV::Client.from_string(
  "couchbase://Administrator:password@127.0.0.1/default",
)

kv.set("crybase:hello", %({"hello":"world"}))
puts String.new(kv.get("crybase:hello"))
kv.touch("crybase:hello", 3600_u32)
puts String.new(kv.get("crybase:hello", expiry: 3600_u32))
kv.delete("crybase:hello")
kv.close
```

Use a TLS KV endpoint with `couchbases://`:

```crystal
kv = CryBase::CouchBase::Services::KV::Client.from_string(
  "couchbases://Administrator:password@127.0.0.1:11207/default?tls_verify=false",
)
```

`tls_verify` defaults to `true`. Pass `tls_hostname:` when the certificate
hostname differs from the endpoint host, or `tls_context:` with a configured
`OpenSSL::SSL::Context::Client` for a custom cluster CA.

### Store Typed KV Values

Include Crystal's `JSON::Serializable` on JSON-backed value types, then use
`get_as`:

```crystal
require "json"
require "crybase"

struct Profile
  include JSON::Serializable

  property name : String
  property score : Int32

  def initialize(@name : String, @score : Int32)
  end
end

kv.set("crybase:profile", Profile.new("ada", 42))
profile = kv.get_as("crybase:profile", Profile)
puts profile.name
```

Values that do not include `JSON::Serializable` are stored with `to_s`; read
them back with `get(key, String)` or raw `get(key)`.

### Use The KV Pool

```crystal
require "crybase"

pool = CryBase::CouchBase::Services::KV::Pool.from_string(
  "couchbase://Administrator:password@127.0.0.1/default",
)

pool.set("crybase:pooled", "value")
puts String.new(pool.get("crybase:pooled"))

pool.checkout do |client|
  client.set("crybase:borrowed", "value")
end

pool.increment("crybase:counter", delta: 2_u64, initial: 10_u64)
pool.decrement("crybase:counter", delta: 1_u64)
pool.touch("crybase:pooled", 3600_u32)

pool.close
```

`KV::Pool` opens 10 connections by default. Override it with `size:`:

```crystal
pool = CryBase::CouchBase::Services::KV::Pool.from_string(
  "couchbase://Administrator:password@127.0.0.1/default",
  size: 20,
)
```

`KV::Pool` accepts the same `tls_verify:`, `tls_hostname:`, and `tls_context:`
options as `KV::Client` and passes them to each pooled connection.

`KV::Client` and `KV::Pool` both expose `get`, `set`, `delete`, `touch`,
`increment`, `decrement`, and `close`. Pass `expiry:` to `get` to fetch a
document and reset expiration atomically.
Each `KV::Pool` operation checks out one authenticated client, delegates the
call, and returns that client to the pool.
`KV::Pool` also exposes `checkout`, `closed?`, `size`, `endpoint`, and `bucket`.

### Use Seed Failover

`KV::Cluster` accepts multiple seed hosts and keeps one active `KV::Pool`.
It tries the next seed if the active seed cannot connect or a delegated
operation hits a connection-level failure. This is seed failover, not
vbucket-map routing.

```crystal
cluster = CryBase::CouchBase::Services::KV::Cluster.from_string(
  "couchbase://Administrator:password@node1,node2,node3/default",
  size: 10,
)

cluster.set("crybase:cluster", "value")
puts String.new(cluster.get("crybase:cluster"))
cluster.close
```

## Public API Map

| Module / Type | Purpose |
| ------------- | ------- |
| `CryBase` | Top-level namespace and shard entry point. |
| `CryBase::CouchBase` | Couchbase-specific namespace. |
| `CryBase::CouchBase::ConnectionString` | Parses supported connection string schemes and seed hosts. |
| `CryBase::CouchBase::Endpoint` | Value type for one Couchbase service endpoint, with `from_string` parsing. |
| `CryBase::CouchBase::Service` | Service enum with plaintext and TLS default ports. |
| `CryBase::CouchBase::Client` | Cluster endpoint enumerator and TCP probe client. |
| `CryBase::CouchBase::Services` | Namespace for service-specific protocol clients. |
| `CryBase::CouchBase::KV` | Alias for `CryBase::CouchBase::Services::KV`. |
| `CryBase::CouchBase::Services::KV` | Couchbase binary KV protocol namespace. |
| `CryBase::CouchBase::Services::KV::Client` | Single authenticated KV connection. |
| `CryBase::CouchBase::Services::KV::Pool` | Fixed-size pool of authenticated KV clients. |
| `CryBase::CouchBase::Services::KV::Cluster` | Seed-failover KV client backed by one active pool. |
| `CryBase::Interfaces` | Abstract interface aliases for connection strings, endpoints, and clients. |

Generated API docs are committed in [`docs/`](docs/index.html).

## Connection Strings

| Scheme | TLS | Notes |
| ------ | --- | ----- |
| `couchbase://` | no | Plaintext service ports. Used by default if the scheme is omitted. |
| `couchbases://` | yes | TLS service ports. |
| `http://` | no | Treated as a Management URL. |
| `https://` | yes | Treated as a Management URL. |

Multiple seed nodes are comma-separated:

```text
couchbase://node1,node2,node3
```

KV connection strings may include credentials, bucket, and supported query
parameters:

```text
couchbases://user:pass@node1:11207/default?tls_verify=false&tls_hostname=cb.local
```

`KV::Client.from_string`, `KV::Pool.from_string`, and `KV::Cluster.from_string`
use `user`, `pass`, and `bucket` from the URI when they are not passed as
arguments. Supported query parameters are `tls_verify` (`true`, `false`, `1`,
`0`) and `tls_hostname`.

An explicit `:port` is currently forwarded to the Management endpoint only.
Other services use their standard Couchbase ports when using
`CryBase::CouchBase::Client` for cluster probing.

For one concrete endpoint, `Endpoint.from_string` uses the first host and
honors an explicit port:

```crystal
CryBase::CouchBase::Endpoint.from_string("couchbase://node1")
# => Data (KV) couchbase://node1:11210

CryBase::CouchBase::Endpoint.from_string("couchbases://node1:11217")
# => Data (KV) couchbases://node1:11217

CryBase::CouchBase::Endpoint.from_string("couchbases://user:pass@node1:11217/default")
# => Data (KV) couchbases://node1:11217

CryBase::CouchBase::Endpoint.from_string(
  "couchbases://node1",
  CryBase::CouchBase::Service::Query,
)
# => Query (N1QL) https://node1:18093
```

## Service Ports

| Service | Plaintext | TLS |
| ------- | --------- | --- |
| Data (KV) | 11210 | 11207 |
| Query (N1QL) | 8093 | 18093 |
| Search (FTS) | 8094 | 18094 |
| Analytics | 8095 | 18095 |
| Index | 9102 | 19102 |
| Eventing | 8096 | 18096 |
| Views | 8092 | 18092 |
| Management | 8091 | 18091 |

## Examples

The `examples/` directory contains:

- `cluster_probe.cr` - probe reachable service endpoints.
- `kv_basics.cr` - run a basic KV set/get flow against one endpoint.
- `kv_cluster.cr` - run a basic KV set/get flow through seed failover.
- `kv_expiration.cr` - run KV expiry, touch, and get-and-touch operations.
- `kv_endpoint_from_cluster.cr` - probe the cluster, pick a KV endpoint, and
  run a KV operation.
- `constants.cr` - shared environment parsing and connection string helpers
  used by the runnable examples.
- `docker-compose.yml` - local Couchbase Community setup for development.

The examples read Couchbase settings through `examples/constants.cr` from
environment variables. The checked-in `examples/.env` file contains the same
defaults for local shells that load it:

```sh
export COUCHBASE_HOST=127.0.0.1
export COUCHBASE_SEEDS=127.0.0.1
export COUCHBASE_KV_PORT=
export COUCHBASE_USER=Administrator
export COUCHBASE_PASS=password
export COUCHBASE_BUCKET=default
export COUCHBASE_TLS=false
export COUCHBASE_TLS_VERIFY=true
export COUCHBASE_TLS_HOSTNAME=
```

When adding another runnable example, require `./constants` and use the shared
connection string helpers instead of reading these variables again in the
example body.

## Development

Run checks:

```sh
crystal tool format --check
crystal build --no-codegen src/crybase.cr
crystal spec --error-trace
```

Generate API docs:

```sh
crystal docs -o docs --project-version=main-dev --source-refname=main
```

Run real Couchbase integration specs:

```sh
COUCHBASE_INTEGRATION=1 crystal spec spec/integration --error-trace
```

Run TLS KV integration specs against a TLS-enabled Couchbase node:

```sh
COUCHBASE_INTEGRATION=1 \
COUCHBASE_TLS=true \
COUCHBASE_TLS_VERIFY=false \
COUCHBASE_KV_PORT=11217 \
COUCHBASE_MANAGEMENT_PORT=8097 \
crystal spec spec/integration --error-trace
```

`COUCHBASE_TLS` and `COUCHBASE_TLS_VERIFY` accept `true`/`false` and `1`/`0`.

Enable local hooks once per clone:

```sh
git config core.hooksPath .githooks
```

The pre-commit hook:

- Checks Crystal formatting.
- Runs Ameba from `bin/ameba` on staged Crystal files.
- Verifies the library builds.
- Regenerates `docs/` with deterministic project metadata.
- Fails if regenerated docs are not staged.
- Runs the spec suite.

## GitHub Actions

CI runs:

- Unit specs.
- Formatting.
- Real Couchbase integration specs against `couchbase:community-7.6.0`.

## Project Conventions

- One flat module per file, for example `module CryBase::CouchBase`.
- Folder paths mirror namespaces.
- Every `class`, `struct`, and `record` has its own file.
- Prefer small value types and explicit protocol framing.
- Keep comments focused on non-obvious behavior.

## Contributing

1. Fork the repository.
2. Create a feature branch.
3. Run format, build, specs, and docs generation.
4. Commit using Conventional Commits.
5. Open a pull request.

## Contributors

- [Anar K. Jafarov](https://github.com/num8er) - creator and maintainer
