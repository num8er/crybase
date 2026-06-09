# Query Service To Do

When starting the next session, continue Query service work from these gaps.

Current Query support already has `Query::Client`, `Query::Cluster`, positional and named args, readonly, scan consistency, client context id, timeout, generic options, TLS, JSON result parsing, warnings/errors, seed failover, Query topology discovery, explicit prepared statements, `adhoc: false`, plan caches, one reprepare attempt for missing prepared statements, and per-query `retry_policy:` values defaulting to `CryBase::CouchBase::RetryPolicy.no_retry`.

Progress:

Completed:

- Query cluster config / topology discovery
  - `Query::Cluster.from_string` now discovers Query nodes through Couchbase Management `nodeServices`.
  - `Query::Cluster#refresh_topology` refreshes Query endpoints explicitly.
  - Query failover attempts refresh discovered topology after transport failures or retryable Query errors.
  - Static Query seed endpoints remain fallback when topology discovery is unavailable.
- Prepared statement support
  - `Query::Client` and `Query::Cluster` now expose `prepare` and `execute_prepared`.
  - `query(..., adhoc: false)` prepares, caches, and executes by prepared name.
  - Cached plans are cleared and prepared again once when Couchbase reports error code `4040`.
- Raw SQL++ mutation examples
  - `examples/query_mutations.cr` runs raw `INSERT`, `UPDATE`, `DELETE`, and
    `UPSERT` statements through `client.query(...)` and `cluster.query(...)`.
  - The example also shows array/object mutation with `SET ... FOR ... END`.
  - Example `User` document keys now use `ULID.generate` from
    `examples/ulid.cr`.
  - Mutation examples avoid `readonly: true` and use `RETURNING` to print
    changed rows.
- Connection reuse / pooling
  - `Query::Client` now reuses one HTTP connection until the client is closed
    or a transport reconnect is required.
  - `Query::Cluster` now caches one reusable `Query::Client` per active Query
    endpoint and closes cached clients on failover, topology replacement, or
    cluster close.
- Scope / collection ergonomics
  - `Query::QueryContext` formats bucket/scope query contexts.
  - Query statement, prepare, and prepared execution paths now accept
    `query_context:`, `bucket:`, `scope:`, and `namespace:`.
- Streaming / typed rows
  - `Query::Client` and `Query::Cluster` now expose `query_as(Type)`,
    `query_each`, and `query_each_as(Type)`.
  - `Query::Result` now exposes `each_row` and `each_row_as(Type)`.
- Retry policy API option
  - `CryBase::CouchBase::Policies::RetryPolicy` exists as a typed retry policy value.
  - `CryBase::CouchBase::RetryPolicy` is the short alias.
  - `Query::Client#query` and `Query::Cluster#query` accept `retry_policy:`.
  - The default policy is `CryBase::CouchBase::RetryPolicy.no_retry`.
  - Automatic retry execution is not implemented yet.

Remaining, in this order:

1. Richer typed Query options
   - Generic `options` exists.
   - Add typed helpers for common N1QL options such as `profile`, `metrics`, `scan_wait`, `max_parallelism`, `pipeline_batch`, `pipeline_cap`, and `query_context`.

2. Retry policy execution
   - Failover exists for transport errors and retryable Query errors.
   - A typed `RetryPolicy` value and per-query `retry_policy:` argument exist.
   - Add the actual retry loop, backoff sleeps, retry budget enforcement, and more granular N1QL error classification.

Recommended next implementation path: richer typed Query options, then retry policy execution.
