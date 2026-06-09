require "../structs"
require "./query_connection_string"
require "./query_seed_hosts"

module CryBaseExamples
  def self.query_cluster_connection_string : String
    query_connection_string(query_seed_hosts, nil, SCHEME, TLS)
  end
end
