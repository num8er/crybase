require "../../src/crybase"

module CryBaseExamples
  HOST         = ENV["COUCHBASE_HOST"]? || "localhost"
  SEEDS        = ENV["COUCHBASE_SEEDS"]? || ENV["COUCHBASE_HOST"]? || "localhost"
  USER         = ENV["COUCHBASE_USER"]? || "Administrator"
  PASS         = ENV["COUCHBASE_PASS"]? || "password"
  BUCKET       = ENV["COUCHBASE_BUCKET"]? || "commerce"
  SCOPE        = ENV["COUCHBASE_SCOPE"]? || CryBase::CouchBase::KV::Constants::DEFAULT_SCOPE
  COLLECTION   = ENV["COUCHBASE_COLLECTION"]? || CryBase::CouchBase::KV::Constants::DEFAULT_COLLECTION
  TLS          = env_bool("COUCHBASE_TLS", false)
  TLS_VERIFY   = env_bool("COUCHBASE_TLS_VERIFY", true)
  TLS_HOSTNAME = env_optional("COUCHBASE_TLS_HOSTNAME")
  KV_PORT      = env_optional("COUCHBASE_KV_PORT")
  QUERY_PORT   = env_optional("COUCHBASE_QUERY_PORT")
  SCHEME       = TLS ? "couchbases" : "couchbase"

  QUERY_SCOPE      = ENV["COUCHBASE_QUERY_SCOPE"]? || SCOPE
  QUERY_COLLECTION = ENV["COUCHBASE_QUERY_COLLECTION"]? || COLLECTION

  QUERY_USER_FIRST_NAMES = [
    "Ada",
    "Grace",
    "Katherine",
    "Margaret",
    "Mary",
    "Radia",
    "Sophie",
    "Valerie",
  ]
  QUERY_USER_LAST_NAMES = [
    "Byron",
    "Hamilton",
    "Hopper",
    "Johnson",
    "Lovelace",
    "Perlman",
    "Ritchie",
    "Wilkes",
  ]
  QUERY_USER_DOMAINS = [
    "example.com",
    "mail.test",
    "users.local",
  ]

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
