require "../spec_helper"
require "http/client"
require "json"

private alias KV = CryBase::CouchBase::Services::KV
private alias Couchbase = CryBase::SpecHelpers::CouchbaseIntegrationHelpers

private module CouchbaseKVIntegrationSpec
  struct Profile
    include JSON::Serializable

    property name : String
    property score : Int32

    def initialize(@name : String, @score : Int32)
    end
  end
end

private alias Profile = CouchbaseKVIntegrationSpec::Profile

describe "Couchbase KV integration" do
  config = Couchbase.config
  keys = [] of String
  kv = uninitialized KV::Client
  pool = uninitialized KV::Pool
  cluster = uninitialized KV::Cluster

  before_all do
    next unless Couchbase.enabled?

    kv = KV::Client.from_string(
      Couchbase.kv_connection_string(config),
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
    pool = KV::Pool.from_string(
      Couchbase.kv_connection_string(config),
      size: 2,
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
    cluster = KV::Cluster.from_string(
      Couchbase.kv_cluster_connection_string(config),
      size: 2,
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
  end

  before_each do
    pending! "set COUCHBASE_INTEGRATION=1 to run real Couchbase integration specs" unless Couchbase.enabled?
  end

  after_each do
    if Couchbase.enabled?
      keys.each do |key|
        kv.delete(key) rescue nil
        pool.delete(key) rescue nil
        cluster.delete(key) rescue nil
      end
      keys.clear
    end
  end

  after_all do
    if Couchbase.enabled?
      kv.close rescue nil
      pool.close rescue nil
      cluster.close rescue nil
    end
  end

  it "stores a document that is visible through Couchbase management" do
    key = "crybase:ci:#{Time.utc.to_unix_ms}"
    keys << key
    value = %({"source":"crybase","kind":"integration"})

    kv.set(key, value)
    String.new(kv.get(key)).should eq(value)

    response = HTTP::Client.get(
      Couchbase.management_document_uri(config, key),
      Couchbase.auth_headers(config)
    )

    response.status_code.should eq(200)
    response.body.should contain(key)
  end

  it "stores and loads a document over TLS when configured" do
    pending! "set COUCHBASE_TLS=true to run TLS KV integration spec" unless config.tls

    key = "crybase:tls:#{Time.utc.to_unix_ms}"
    keys << key

    kv.set(key, "tls-ok")
    String.new(kv.get(key)).should eq("tls-ok")
  end

  it "stores and loads through a scoped collection context" do
    key = "crybase:collection:#{Time.utc.to_unix_ms}"
    keys << key

    users = kv.scope("_default").collection("_default")

    users.set(key, "scoped-ok")
    String.new(users.get(key)).should eq("scoped-ok")
    users.delete(key)
    keys.delete(key)
  end

  it "stores and loads through connection-level scoped collection defaults" do
    key = "crybase:collection:default:#{Time.utc.to_unix_ms}"
    pool_key = "#{key}:pool"
    cluster_key = "#{key}:cluster"
    keys << key
    keys << pool_key
    keys << cluster_key

    kv.bucket = config.bucket
    kv.scope = "_default"
    kv.collection = "_default"
    kv.collection("_default").set(key, "client-default-context")
    String.new(kv.get(key)).should eq("client-default-context")

    pool.bucket = config.bucket
    pool.scope = "_default"
    pool.collection = "_default"
    pool.collection("_default").set(pool_key, "pool-default-context")
    String.new(pool.get(pool_key)).should eq("pool-default-context")

    cluster.bucket = config.bucket
    cluster.scope = "_default"
    cluster.collection = "_default"
    cluster.collection("_default").set(cluster_key, "cluster-default-context")
    String.new(cluster.get(cluster_key)).should eq("cluster-default-context")
  end

  it "reuses pooled connections for KV operations" do
    key = "crybase:pool:#{Time.utc.to_unix_ms}"
    checkout_key = "#{key}:checkout"
    keys << key
    keys << checkout_key

    pool.set(key, "pooled")
    String.new(pool.get(key)).should eq("pooled")

    pool.checkout do |client|
      client.set(checkout_key, "borrowed")
      String.new(client.get(checkout_key)).should eq("borrowed")
    end
  end

  it "increments and decrements counters" do
    key = "crybase:counter:#{Time.utc.to_unix_ms}"
    keys << key

    kv.increment(key, delta: 2_u64, initial: 10_u64).should eq(10_u64)
    kv.increment(key, delta: 5_u64).should eq(15_u64)
    kv.decrement(key, delta: 3_u64).should eq(12_u64)
  end

  it "increments and decrements counters through the pool" do
    key = "crybase:pool:counter:#{Time.utc.to_unix_ms}"
    keys << key

    pool.increment(key, delta: 4_u64, initial: 20_u64).should eq(20_u64)
    pool.increment(key, delta: 6_u64).should eq(26_u64)
    pool.decrement(key, delta: 10_u64).should eq(16_u64)
  end

  it "touches document expiration" do
    key = "crybase:touch:#{Time.utc.to_unix_ms}"
    keys << key

    kv.set(key, "alive", expiry: 2_u32)
    sleep 1.second
    kv.touch(key, 10_u32)
    sleep 2.seconds

    String.new(kv.get(key)).should eq("alive")
  end

  it "gets and resets expiration atomically" do
    key = "crybase:get-touch:#{Time.utc.to_unix_ms}"
    keys << key

    pool.set(key, "alive", expiry: 2_u32)
    sleep 1.second

    String.new(pool.get(key, expiry: 10_u32)).should eq("alive")
    sleep 2.seconds

    String.new(pool.get(key)).should eq("alive")
  end

  it "stores and loads typed JSON values with get_as" do
    key = "crybase:typed:#{Time.utc.to_unix_ms}"
    pool_key = "#{key}:pool"
    keys << key
    keys << pool_key
    profile = Profile.new("ada", 42)

    kv.set(key, profile)
    loaded = kv.get_as(key, Profile)
    loaded.name.should eq("ada")
    loaded.score.should eq(42)

    pool.set(pool_key, profile)
    loaded_from_pool = pool.get_as(pool_key, Profile)
    loaded_from_pool.name.should eq("ada")
    loaded_from_pool.score.should eq(42)
  end

  it "stores and loads through a seed-failover cluster" do
    key = "crybase:cluster:#{Time.utc.to_unix_ms}"
    keys << key

    cluster.set(key, "cluster-ok")
    String.new(cluster.get(key)).should eq("cluster-ok")
  end
end
