require "../structs"
require "./kv_connection_string"

module CryBaseExamples
  def self.open_kv_client : CryBase::CouchBase::KV::Client
    CryBase::CouchBase::KV::Client.from_string(
      kv_connection_string,
      tls_verify: TLS_VERIFY,
      tls_hostname: TLS_HOSTNAME,
    )
  end
end
