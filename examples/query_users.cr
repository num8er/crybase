require "json"
require "./constants"
require "./ulid"

struct CryBaseExamples::QueryUser
  include JSON::Serializable

  getter id : String
  getter type : String
  getter name : String
  getter email : String
  getter? active : Bool

  def initialize(
    @id : String,
    @name : String,
    @email : String,
    @active : Bool,
    @type : String = "User",
  )
  end
end

module CryBaseExamples
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

  def self.open_kv_client : CryBase::CouchBase::KV::Client
    CryBase::CouchBase::KV::Client.from_string(
      kv_connection_string,
      tls_verify: TLS_VERIFY,
      tls_hostname: TLS_HOSTNAME,
    )
  end

  def self.open_query_client : CryBase::CouchBase::Query::Client
    CryBase::CouchBase::Query::Client.from_string(
      query_connection_string,
      tls_verify: TLS_VERIFY,
      tls_hostname: TLS_HOSTNAME,
    )
  end

  def self.open_query_cluster : CryBase::CouchBase::Query::Cluster
    CryBase::CouchBase::Query::Cluster.from_string(
      query_cluster_connection_string,
      tls_verify: TLS_VERIFY,
      tls_hostname: TLS_HOSTNAME,
    )
  end

  def self.seed_query_users(
    kv : CryBase::CouchBase::KV::Client,
    count : Int32 = 8,
  ) : Array(QueryUser)
    random = Random.new(20_260_529)

    Array(QueryUser).new(count) do |index|
      user = random_query_user(random, index)
      kv.set(user.id, user)
      user
    end
  end

  def self.delete_query_users(
    kv : CryBase::CouchBase::KV::Client,
    users : Array(QueryUser),
  ) : Nil
    users.each do |user|
      kv.delete(user.id) rescue nil
    end
  end

  def self.query_user_keys(users : Array(QueryUser)) : Array(String)
    users.map(&.id)
  end

  def self.n1ql_bucket : String
    "`#{BUCKET.gsub("`", "``")}`"
  end

  private def self.random_query_user(random : Random, index : Int32) : QueryUser
    id = "User:#{ULID.generate}"
    first_name = QUERY_USER_FIRST_NAMES[random.rand(QUERY_USER_FIRST_NAMES.size)]
    last_name = QUERY_USER_LAST_NAMES[random.rand(QUERY_USER_LAST_NAMES.size)]
    name = "#{first_name} #{last_name}"
    email_name = "#{first_name}.#{last_name}.#{index}".downcase
    domain = QUERY_USER_DOMAINS[random.rand(QUERY_USER_DOMAINS.size)]
    active = index == 0 || random.rand(2) == 0

    QueryUser.new(id, name, "#{email_name}@#{domain}", active)
  end
end
