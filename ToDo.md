# Query Service To Do

When starting the next session, continue Query service work from these gaps.

Current Query support already has `Query::Client`, `Query::Cluster`, positional and named args, readonly, scan consistency, client context id, timeout, generic options, TLS, JSON result parsing, warnings/errors, seed failover, and Query topology discovery.

Progress:

Completed:

- Query cluster config / topology discovery
  - `Query::Cluster.from_string` now discovers Query nodes through Couchbase Management `nodeServices`.
  - `Query::Cluster#refresh_topology` refreshes Query endpoints explicitly.
  - Query failover attempts refresh discovered topology after transport failures or retryable Query errors.
  - Static Query seed endpoints remain fallback when topology discovery is unavailable.

Remaining, in this order:

1. Prepared statement support
   - Add prepare/execute-prepared APIs.
   - Decide `adhoc` option behavior.
   - Add prepared plan cache and retry handling for invalidated prepared statements.

2. Connection reuse / pooling
   - Query currently opens an HTTP client per request and sends `Connection: close`.
   - Add persistent HTTP client reuse or a Query connection pool.

3. Richer typed Query options
   - Generic `options` exists.
   - Add typed helpers for common N1QL options such as `profile`, `metrics`, `scan_wait`, `max_parallelism`, `pipeline_batch`, `pipeline_cap`, and `query_context`.

4. Scope / collection ergonomics
   - Add bucket/scope-aware Query context helpers.
   - Today callers can pass `query_context` through generic options, but there is no first-class API.

5. Streaming / typed rows
   - Results are currently parsed into `JSON::Any` rows.
   - Add streaming row reader and typed row mapping such as `query_as(Type)`.

6. Retry policy
   - Failover exists for transport errors and retryable Query errors.
   - Add configurable retry policy, backoff, retry budget, and more granular N1QL error classification.

Recommended next implementation path: prepared statements, then connection reuse/pooling.
