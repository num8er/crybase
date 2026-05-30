require "../structs"
require "./query_cluster_connection_string"

module CryBaseExamples
  def self.open_query_cluster : CryBase::CouchBase::Query::Cluster
    CryBase::CouchBase::Query::Cluster.from_string(
      query_cluster_connection_string,
      tls_verify: TLS_VERIFY,
      tls_hostname: TLS_HOSTNAME,
    )
  end
end
