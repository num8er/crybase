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

CryBase is still early, but it now has three useful layers:

- A cluster-level client that expands Couchbase connection strings into service
  endpoints and TCP-probes them.
- A KV client that speaks the Couchbase binary protocol over plaintext or TLS
  sockets for authenticated `get`, `set`, `delete`, `touch`, and counter
  operations, plus fixed-size and seed-failover connection pools.
- A Query client that posts N1QL/SQL++ statements to the Couchbase HTTP Query
  service, with reusable HTTP connections, JSON result parsing, prepared
  statements, typed row helpers, streaming cursors, seed failover, and Query
  node discovery.

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
- Query service N1QL/SQL++ execution over reusable HTTP/HTTPS connections.
- Query prepared statement APIs and `adhoc: false` plan caching.
- Query typed row helpers, streaming row iteration, streaming cursors, and
  bucket/scope query context helpers.
- Per-query Query retry policy values with
  `CryBase::CouchBase::RetryPolicy.no_retry` as the default.
- `Query::Cluster` seed failover across multiple Query hosts.
- `Query::Cluster` Query node discovery from Couchbase cluster topology.
- Real Couchbase integration specs in GitHub Actions.

Not implemented yet:

- KV cluster config loading and node/vbucket map routing.
- Automatic retry/reconnect execution, durability, observe, CAS helpers,
  scopes, or collections.
- Search, Analytics, Index, Eventing, Views, and Management protocols.

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

### Run N1QL Queries

Use `Query::Client` for one Query endpoint:

```crystal
client = CryBase::CouchBase::Query::Client.from_string(
  "couchbase://Administrator:password@127.0.0.1",
)

result = client.query(
  "SELECT $name AS name, $score AS score",
  named_args: {name: "crybase", score: 42},
  readonly: true,
)

puts result.rows.first["name"].as_s
```

`readonly: true` marks a Query request as read-only and sends the Couchbase
Query `readonly=true` option. Use it for `SELECT` and other non-mutating
statements. Leave it unset for `INSERT`, `UPDATE`, `UPSERT`, `DELETE`, and
other mutations.

Use bucket/scope context helpers when your statement should resolve collection
names relative to a Couchbase scope:

```crystal
context = CryBase::CouchBase::Query::QueryContext.new(
  "travel-sample",
  "inventory",
)

result = client.query(
  "SELECT META(u).id AS doc_key, u.name FROM users AS u",
  query_context: context,
  readonly: true,
)
```

Use `bucket:` and `scope:` as shorthand when you do not need to keep a context
object:

```crystal
result = client.query(
  "SELECT META(u).id AS doc_key, u.name FROM users AS u",
  bucket: "travel-sample",
  scope: "inventory",
  readonly: true,
)
```

Pass positional parameters after the statement:

```crystal
result = client.query("SELECT $1 AS query_value", "hello", readonly: true)
puts result.rows.first["query_value"].as_s
```

Use typed scan consistency values when needed:

```crystal
result = client.query(
  "SELECT 1 AS one",
  scan_consistency: CryBase::CouchBase::Query::ScanConsistency::RequestPlus,
)
```

Pass a per-query retry policy when a call should carry explicit retry intent.
`CryBase::CouchBase::RetryPolicy.no_retry` is the default. Passing a policy
currently does not add automatic retry execution; it keeps the policy separate
from the N1QL form options for the future retry path.

```crystal
policy = CryBase::CouchBase::RetryPolicy.new(
  max_attempts: 3,
  delay: 50.milliseconds,
  jitter: 0.2,
  max_elapsed: 500.milliseconds,
)

result = client.query(
  "SELECT 1 AS one",
  readonly: true,
  retry_policy: policy,
)
```

`Query::Cluster.from_string` accepts multiple seed hosts, loads Query node
topology from Couchbase Management when available, and falls back to the
original Query seed endpoints when topology discovery is unavailable. It tries
the next endpoint when a transport failure or retryable Query service HTTP
error occurs.

```crystal
cluster = CryBase::CouchBase::Query::Cluster.from_string(
  "couchbase://Administrator:password@node1,node2,node3",
)

puts cluster.query("SELECT 1 AS one").rows.first["one"].as_i
cluster.close
```

`Query::Client` reuses its HTTP connection until `close`. `Query::Cluster`
keeps one reusable endpoint client per discovered Query endpoint and closes
stale clients when topology changes or failover replaces the active endpoint.

Prepare a statement explicitly when you want to manage the prepared plan:

```crystal
prepared = client.prepare(
  "SELECT $name AS name, $score AS score",
  readonly: true,
)

result = client.execute_prepared(
  prepared,
  named_args: {name: "crybase", score: 42},
  readonly: true,
)

puts result.rows.first["score"].as_i
```

`adhoc: true` is the default and sends the statement directly as a one-off
Query request. Pass `adhoc: false` when the same statement shape will be reused:
CryBase prepares the statement, caches the prepared plan, and executes by
prepared name. If Couchbase reports that the prepared statement no longer
exists, CryBase clears that cache entry and prepares it once again.

```crystal
result = client.query(
  "SELECT $1 AS query_value",
  "cached",
  readonly: true,
  adhoc: false,
)

puts result.rows.first["query_value"].as_s
client.close
```

Map rows into Crystal types with `query_as`, stream rows through a block with
`query_each_as`, or keep a single-use streaming cursor with `query_cursor`:

```crystal
struct UserRow
  include JSON::Serializable

  getter doc_key : String
  getter name : String
end

rows = client.query_as(
  UserRow,
  "SELECT META(u).id AS doc_key, u.name FROM users AS u",
  bucket: "travel-sample",
  scope: "inventory",
  readonly: true,
)

client.query_each_as(
  UserRow,
  "SELECT META(u).id AS doc_key, u.name FROM users AS u",
  bucket: "travel-sample",
  scope: "inventory",
  readonly: true,
) do |row|
  puts row.name
end

cursor = client.query_cursor(
  "SELECT META(u).id AS doc_key, u.name FROM users AS u",
  bucket: "travel-sample",
  scope: "inventory",
  readonly: true,
)

result = cursor.each_as(UserRow) do |row|
  puts row.name
end

puts result.metrics
```

`query_cursor` starts the request when `each` or `each_as` is called. It yields
rows as the response body is parsed and does not retain them in
`result.rows`.

Run raw SQL++ mutation statements through `query` too. Do not pass
`readonly: true` for mutations; use `RETURNING` when you want changed rows
back.

```crystal
result = client.query(
  <<-SQL,
    UPDATE users AS u
    USE KEYS $id
    SET event.done = true FOR event IN u.events WHEN event.name = $event END
    WHERE u.type = "User"
    RETURNING META(u).id AS doc_key, u.events
    SQL
  named_args: {id: "User:01...", event: "welcome"},
  bucket: "travel-sample",
  scope: "inventory",
)
```

If the Management API uses a non-default port, pass `management_port:`. Use
`discover_topology: false` to keep static seed-only routing.

```crystal
cluster = CryBase::CouchBase::Query::Cluster.from_string(
  "couchbase://Administrator:password@node1,node2",
  management_port: 19091,
)

cluster.refresh_topology
cluster.close
```

## Public API Map

| Module / Type | Purpose |
| ------------- | ------- |
| `CryBase` | Top-level namespace and shard entry point. |
| `CryBase::Connectivity` | Shared plaintext TCP and TLS socket construction helpers, including `host:port` overloads. |
| `CryBase::Connectivity::HostPort` | Strict parser/value object for `host:port` strings. |
| `CryBase::Connectivity::SocketConfig` | Shared timeout and TLS socket options. |
| `CryBase::CouchBase` | Couchbase-specific namespace. |
| `CryBase::CouchBase::ConnectionString` | Parses supported connection string schemes and seed hosts. |
| `CryBase::CouchBase::Endpoint` | Value type for one Couchbase service endpoint, with `from_string` parsing. |
| `CryBase::CouchBase::Service` | Service enum with plaintext and TLS default ports. |
| `CryBase::CouchBase::Client` | Cluster endpoint enumerator and TCP probe client. |
| `CryBase::CouchBase::Policies::RetryPolicy` | Canonical per-query retry policy value. |
| `CryBase::CouchBase::RetryPolicy` | Short alias for `Policies::RetryPolicy`. |
| `CryBase::CouchBase::Services` | Namespace for service-specific protocol clients. |
| `CryBase::CouchBase::KV` | Alias for `CryBase::CouchBase::Services::KV`. |
| `CryBase::CouchBase::Query` | Alias for `CryBase::CouchBase::Services::Query`. |
| `CryBase::CouchBase::Services::KV` | Couchbase binary KV protocol namespace. |
| `CryBase::CouchBase::Services::KV::Client` | Single authenticated KV connection. |
| `CryBase::CouchBase::Services::KV::Pool` | Fixed-size pool of authenticated KV clients. |
| `CryBase::CouchBase::Services::KV::Cluster` | Seed-failover KV client backed by one active pool. |
| `CryBase::CouchBase::Services::Query` | Couchbase HTTP Query service namespace. |
| `CryBase::CouchBase::Services::Query::Client` | Authenticated N1QL/SQL++ Query endpoint client. |
| `CryBase::CouchBase::Services::Query::Cluster` | Query client over discovered topology with seed fallback. |
| `CryBase::CouchBase::Services::Query::Cursor` | Single-use streaming Query row cursor. |
| `CryBase::CouchBase::Services::Query::QueryContext` | Bucket/scope Query context formatter. |
| `CryBase::CouchBase::Services::Query::PreparedStatement` | Prepared Query statement name and metadata. |
| `CryBase::CouchBase::Services::Query::Result` | Parsed Query response rows, metadata, warnings, and errors. |
| `CryBase::CouchBase::Services::Query::Topology` | Parsed Query endpoints from Couchbase nodeServices payloads. |
| `CryBase::CouchBase::Services::Query::TopologyClient` | Authenticated Management API client for Query topology loading. |
| `CryBase::Interfaces` | Abstract interface aliases for connection strings, endpoints, and clients. |

Generated API docs are committed in [`docs/`](docs/index.html).

Feature notes:

- [KV Client](docs/1.FEAT_kv-client.md)
- [KV Client Pool](docs/2.FEAT_kv-client-pool.md)
- [Connection String To Endpoint Conversion](docs/3.FEAT_connection-string-to-endpoint-conversion.md)
- [KV Cluster](docs/4.FEAT_kv-cluster.md)
- [Query Service](docs/5.FEAT_query-service.md)
- [Connectivity](docs/6.FEAT_connectivity.md)
- [Query Topology Discovery](docs/7.FEAT_query-topology-discovery.md)
- [Query Prepared Statements](docs/8.FEAT_query-prepared-statements.md)
- [Query Reuse Context And Typed Rows](docs/9.FEAT_query-reuse-context-and-typed-rows.md)
- [Query Cursor](docs/10.FEAT_query-cursor.md)
- [Examples Layout](docs/11.FEAT_examples-layout.md)
- [Query Retry Policy Option](docs/12.FEAT_query-retry-policy-option.md)

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
arguments. `Query::Client.from_string` and `Query::Cluster.from_string` use
`user` and `pass` from the URI. Supported query parameters are `tls_verify`
(`true`, `false`, `1`, `0`), `tls_hostname`, and `network` for topology
alternate address selection.

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

The `examples/` directory contains one runnable entry point per example:

- `cluster_probe/example.cr` - probe reachable service endpoints.
- `kv_basics/example.cr` - run a basic KV set/get flow against one endpoint.
- `kv_cluster/example.cr` - run a basic KV set/get flow through seed failover.
- `kv_expiration/example.cr` - run KV expiry, touch, and get-and-touch
  operations.
- `kv_endpoint_from_cluster/example.cr` - probe the cluster, pick a KV
  endpoint, and run a KV operation.
- `query_basics/example.cr` - seed `type = "User"` documents with ULID keys
  and query them with bucket/scope context, `query_as`, `query_each_as`, and
  `query_cursor`.
- `query_cursor/example.cr` - stream seeded `type = "User"` documents through
  `Query::Cursor#each_as`.
- `query_prepared/example.cr` - seed `type = "User"` documents with ULID keys,
  prepare a N1QL statement with query context, and run it with explicit and
  `adhoc: false` prepared execution.
- `query_retry_policy/example.cr` - pass an explicit
  `CryBase::CouchBase::RetryPolicy` to client and cluster Query calls.
- `query_mutations/example.cr` - run raw SQL++ `INSERT`, `UPDATE`, `DELETE`,
  `UPSERT`, and `SET ... FOR ... END` mutations through Query using query
  context.
- `shared/constants.cr` - shared environment parsing.
- `shared/methods.cr` - entry point for shared example helper methods.
- `shared/methods/*.cr` - one shared helper method per file.
- `shared/structs.cr` - entry point for shared example document and row types
  under `CryBaseExamples::Structs`.
- `shared/structs/*.cr` - one shared example struct per file.
- `shared/ulid.cr` - timestamp-based ULID utility for example document keys.
- `docker-compose.yml` - local Couchbase Community setup for development.

Run an example with its directory entry point:

```sh
crystal run examples/query_basics/example.cr
```

The examples read Couchbase settings through `examples/shared/constants.cr`
from environment variables. The checked-in `examples/.env` file contains the
same defaults for local shells that load it:

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
export COUCHBASE_QUERY_PORT=
```

When adding another runnable example, put it in
`examples/<example_name>/example.cr`, require `../shared/methods`, put shared
types in `examples/shared/structs/<name>.cr` under
`CryBaseExamples::Structs`, local types in
`examples/<example_name>/structs/<name>.cr`, and only add
`examples/<example_name>/helpers.cr` for helpers used by that example.

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
find docs -name '*.html' -print0 | xargs -0 perl -pi -e 's/[ \t]+$//'
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
- Strips trailing whitespace from generated HTML docs.
- Fails if regenerated docs are not staged.
- Runs the spec suite.

## GitHub Actions

CI runs:

- Unit specs.
- Formatting.
- Real Couchbase integration specs against `couchbase:community-7.6.0` and
  `couchbase:community-8.0.0`.
- Real Couchbase Query TLS integration specs against
  `couchbase:enterprise-7.6.0` and `couchbase:enterprise-8.0.0`.

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
