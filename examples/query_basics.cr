require "./constants"

query = CryBase::CouchBase::Query::Client.from_string(
  CryBaseExamples.query_connection_string,
  tls_verify: CryBaseExamples::TLS_VERIFY,
  tls_hostname: CryBaseExamples::TLS_HOSTNAME,
)

result = query.query(
  "SELECT $name AS name, $score AS score",
  named_args: {name: "crybase", score: 42},
  readonly: true,
)

puts result.rows.first.to_json
query.close
