require "uri"
require "../src/crybase"

module CryBaseExamples
  HOST         = ENV["COUCHBASE_HOST"]? || "localhost"
  SEEDS        = ENV["COUCHBASE_SEEDS"]? || ENV["COUCHBASE_HOST"]? || "localhost"
  USER         = ENV["COUCHBASE_USER"]? || "Administrator"
  PASS         = ENV["COUCHBASE_PASS"]? || "password"
  BUCKET       = ENV["COUCHBASE_BUCKET"]? || "default"
  TLS          = env_bool("COUCHBASE_TLS", false)
  TLS_VERIFY   = env_bool("COUCHBASE_TLS_VERIFY", true)
  TLS_HOSTNAME = env_optional("COUCHBASE_TLS_HOSTNAME")
  KV_PORT      = env_optional("COUCHBASE_KV_PORT")
  SCHEME       = TLS ? "couchbases" : "couchbase"

  def self.cluster_connection_string : String
    "#{SCHEME}://#{HOST}"
  end

  def self.kv_connection_string : String
    kv_connection_string(HOST, KV_PORT, SCHEME, TLS)
  end

  def self.kv_connection_string(endpoint : CryBase::CouchBase::Endpoint) : String
    kv_connection_string("#{endpoint.host}:#{endpoint.port}", nil, endpoint.scheme, endpoint.tls?)
  end

  def self.kv_cluster_connection_string : String
    kv_connection_string(seed_hosts, nil, SCHEME, TLS)
  end

  private def self.kv_connection_string(host : String, port : String?, scheme : String, tls : Bool) : String
    host_port = port ? "#{host}:#{port}" : host
    "#{scheme}://#{URI.encode_www_form(USER)}:#{URI.encode_www_form(PASS)}@#{host_port}/#{URI.encode_www_form(BUCKET)}#{tls_query_string(tls)}"
  end

  private def self.seed_hosts : String
    return SEEDS if SEEDS.includes?(":") || KV_PORT.nil?

    "#{SEEDS}:#{KV_PORT}"
  end

  private def self.tls_query_string(tls : Bool) : String
    query = [] of String
    query << "tls_verify=#{TLS_VERIFY}" if tls
    if tls_hostname = TLS_HOSTNAME
      query << "tls_hostname=#{URI.encode_www_form(tls_hostname)}"
    end
    query.empty? ? "" : "?#{query.join('&')}"
  end

  private def self.env_bool(name : String, default : Bool) : Bool
    case ENV[name]?.try(&.strip.downcase)
    when "1", "true"  then true
    when "0", "false" then false
    else                   default
    end
  end

  private def self.env_optional(name : String) : String?
    value = ENV[name]?
    return nil unless value

    value.empty? ? nil : value
  end
end
