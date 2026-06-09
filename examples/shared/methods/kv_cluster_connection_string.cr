require "../structs"
require "./kv_connection_string"
require "./seed_hosts"

module CryBaseExamples
  def self.kv_cluster_connection_string : String
    kv_connection_string(seed_hosts, nil, SCHEME, TLS)
  end
end
