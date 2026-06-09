require "uri"
require "../structs"

module CryBaseExamples
  private def self.tls_query_string(tls : Bool) : String
    query = [] of String
    query << "tls_verify=#{TLS_VERIFY}" if tls
    if tls_hostname = TLS_HOSTNAME
      query << "tls_hostname=#{URI.encode_www_form(tls_hostname)}"
    end
    query.empty? ? "" : "?#{query.join('&')}"
  end
end
