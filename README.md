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
[![Couchbase KV](https://img.shields.io/badge/Couchbase-KV%20Client-EA2328?logo=couchbase&logoColor=white)](https://www.couchbase.com/)
[![Couchbase Query](https://img.shields.io/badge/Couchbase-Query%20Client-EA2328?logo=couchbase&logoColor=white)](https://www.couchbase.com/)

Crystal client primitives for Couchbase.

CryBase currently covers Couchbase endpoint discovery, the KV binary protocol
with bucket vbucket-count discovery, and the Query HTTP service. Search,
Analytics, Index, Eventing, Views, and Management protocol clients are not
implemented yet.

## Index

1. [Glossary](docs/1.MANUAL_glossary.md)
2. [Installation](docs/2.MANUAL_installation.md)
3. [Quick start](docs/3.MANUAL_quick-start.md)
4. [Key Value service](docs/4.MANUAL_key-value-service.md)
5. [Query service](docs/5.MANUAL_query-service.md)

## Small Use Cases

```crystal
kv = CryBase::CouchBase::KV::Client.from_string(
  "couchbase://Administrator:password@127.0.0.1/commerce",
)

kv.scope = "ecommerce_shop"
kv.collection = "users"
kv.set("user:1", %({"name":"Ada"}))
puts String.new(kv.get("user:1"))

admins = kv.collection("admins")
admins.set("admin:1", %({"name":"Grace"}))
```

```crystal
query = CryBase::CouchBase::Query::Client.from_string(
  "couchbase://Administrator:password@127.0.0.1/commerce",
)

query.scope = "ecommerce_shop"

rows = query.query(
  "SELECT META(u).id AS doc_key, u.name FROM users AS u LIMIT 5",
)
```
