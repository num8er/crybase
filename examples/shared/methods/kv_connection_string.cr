require "uri"
require "../structs"
require "./tls_query_string"

module CryBaseExamples
  def self.kv_connection_string : String
    kv_connection_string(HOST, KV_PORT, SCHEME, TLS)
  end

  def self.kv_connection_string(endpoint : CryBase::CouchBase::Endpoint) : String
    kv_connection_string("#{endpoint.host}:#{endpoint.port}", nil, endpoint.scheme, endpoint.tls?)
  end

  private def self.kv_connection_string(host : String, port : String?, scheme : String, tls : Bool) : String
    host_port = port ? "#{host}:#{port}" : host
    "#{scheme}://#{URI.encode_www_form(USER)}:#{URI.encode_www_form(PASS)}@#{host_port}/#{URI.encode_www_form(BUCKET)}#{tls_query_string(tls)}"
  end
end
