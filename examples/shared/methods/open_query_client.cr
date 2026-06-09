require "../structs"
require "./query_connection_string"

module CryBaseExamples
  def self.open_query_client : CryBase::CouchBase::Query::Client
    CryBase::CouchBase::Query::Client.from_string(
      query_connection_string,
      tls_verify: TLS_VERIFY,
      tls_hostname: TLS_HOSTNAME,
    )
  end
end
