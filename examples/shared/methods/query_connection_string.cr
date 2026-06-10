require "uri"
require "../structs"
require "./tls_query_string"

module CryBaseExamples
  def self.query_connection_string : String
    query_connection_string(HOST, QUERY_PORT, SCHEME, TLS)
  end

  private def self.query_connection_string(host : String, port : String?, scheme : String, tls : Bool) : String
    host_port = port ? "#{host}:#{port}" : host
    "#{scheme}://#{URI.encode_www_form(USER)}:#{URI.encode_www_form(PASS)}@#{host_port}/#{URI.encode_www_form(BUCKET)}#{tls_query_string(tls)}"
  end
end
