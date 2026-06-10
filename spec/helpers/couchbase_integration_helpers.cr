require "base64"

module CryBase::SpecHelpers::CouchbaseIntegrationHelpers
  private alias CB = CryBase::CouchBase

  def self.enabled? : Bool
    ENV["COUCHBASE_INTEGRATION"]? == "1"
  end

  def self.config : Config
    tls = env_bool("COUCHBASE_TLS", false)
    tls_hostname = ENV["COUCHBASE_TLS_HOSTNAME"]?
    tls_hostname = nil if tls_hostname && tls_hostname.empty?

    Config.new(
      host: ENV["COUCHBASE_HOST"]? || "127.0.0.1",
      seeds: ENV["COUCHBASE_SEEDS"]? || ENV["COUCHBASE_HOST"]? || "127.0.0.1",
      user: ENV["COUCHBASE_USER"]? || "Administrator",
      pass: ENV["COUCHBASE_PASS"]? || "password",
      bucket: ENV["COUCHBASE_BUCKET"]? || "commerce",
      management_port: env_int("COUCHBASE_MANAGEMENT_PORT", 8091),
      kv_port: env_int("COUCHBASE_KV_PORT", CB::Service::KV.default_port(tls)),
      query_port: env_int("COUCHBASE_QUERY_PORT", CB::Service::Query.default_port(tls)),
      tls: tls,
      tls_verify: env_bool("COUCHBASE_TLS_VERIFY", true),
      tls_hostname: tls_hostname,
    )
  end

  def self.kv_endpoint(config : Config) : CB::Endpoint
    scheme = config.tls ? "couchbases" : "couchbase"
    CB::Endpoint.from_string("#{scheme}://#{config.host}:#{config.kv_port}", CB::Service::KV)
  end

  def self.kv_connection_string(config : Config) : String
    scheme = config.tls ? "couchbases" : "couchbase"
    "#{scheme}://#{URI.encode_www_form(config.user)}:#{URI.encode_www_form(config.pass)}@#{config.host}:#{config.kv_port}/#{URI.encode_www_form(config.bucket)}"
  end

  def self.kv_cluster_connection_string(config : Config) : String
    scheme = config.tls ? "couchbases" : "couchbase"
    seeds = config.seeds.includes?(":") ? config.seeds : "#{config.seeds}:#{config.kv_port}"
    "#{scheme}://#{URI.encode_www_form(config.user)}:#{URI.encode_www_form(config.pass)}@#{seeds}/#{URI.encode_www_form(config.bucket)}"
  end

  def self.query_connection_string(config : Config) : String
    scheme = config.tls ? "couchbases" : "couchbase"
    "#{scheme}://#{URI.encode_www_form(config.user)}:#{URI.encode_www_form(config.pass)}@#{config.host}:#{config.query_port}/#{URI.encode_www_form(config.bucket)}"
  end

  def self.query_cluster_connection_string(config : Config) : String
    scheme = config.tls ? "couchbases" : "couchbase"
    seeds = config.seeds.includes?(":") ? config.seeds : "#{config.seeds}:#{config.query_port}"
    "#{scheme}://#{URI.encode_www_form(config.user)}:#{URI.encode_www_form(config.pass)}@#{seeds}/#{URI.encode_www_form(config.bucket)}"
  end

  def self.management_document_uri(config : Config, key : String) : URI
    encoded_key = URI.encode_path_segment(key)
    URI.parse("http://#{config.host}:#{config.management_port}/pools/default/buckets/#{config.bucket}/scopes/_default/collections/_default/docs/#{encoded_key}")
  end

  def self.auth_headers(config : Config) : HTTP::Headers
    HTTP::Headers{"Authorization" => "Basic #{Base64.strict_encode("#{config.user}:#{config.pass}")}"}
  end

  private def self.env_bool(name : String, default : Bool) : Bool
    value = ENV[name]?.try(&.strip.downcase)
    case value
    when "1", "true"  then true
    when "0", "false" then false
    else                   default
    end
  end

  private def self.env_int(name : String, default : Int32) : Int32
    ENV[name]?.try(&.to_i?) || default
  end
end
