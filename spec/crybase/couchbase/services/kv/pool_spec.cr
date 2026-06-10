require "../../../../spec_helper"

private alias CB = CryBase::CouchBase
private alias KV = CryBase::CouchBase::Services::KV

describe KV::Pool do
  it "uses 10 connections by default" do
    KV::Pool::DEFAULT_SIZE.should eq(10)
  end

  it "requires at least one connection" do
    endpoint = CB::Endpoint.new("127.0.0.1", 11210, CB::Service::KV, false)

    expect_raises(ArgumentError, /pool size/) do
      KV::Pool.new(endpoint, "user", "pass", "bucket", size: 0)
    end
  end

  it "exposes delegated client operations" do
    pool = uninitialized KV::Pool

    typeof(pool.bucket = "bucket").should eq(String)
    typeof(pool.scope).should eq(String)
    typeof(pool.scope = "ecommerce_shop").should eq(String)
    typeof(pool.collection).should eq(String)
    typeof(pool.collection = "users").should eq(String)
    typeof(pool.scope("ecommerce_shop")).should eq(KV::ScopeContext(KV::Pool))
    typeof(pool.scope("ecommerce_shop").collection("users")).should eq(KV::CollectionContext(KV::Pool))
    typeof(pool.collection("users")).should eq(KV::CollectionContext(KV::Pool))
    typeof(pool.get("key")).should eq(Bytes)
    typeof(pool.get("key", collection_id: 1_u32)).should eq(Bytes)
    typeof(pool.get("key", expiry: 1_u32)).should eq(Bytes)
    typeof(pool.get_as("key", String)).should eq(String)
    typeof(pool.get("key", String)).should eq(String)
    typeof(pool.set("key", "value")).should eq(UInt64)
    typeof(pool.set("key", "value", collection_id: 1_u32)).should eq(UInt64)
    typeof(pool.set("key", "value", expiry: 1_u32)).should eq(UInt64)
    typeof(pool.delete("key")).should eq(Nil)
    typeof(pool.touch("key", 1_u32)).should eq(UInt64)
    typeof(pool.increment("key")).should eq(UInt64)
    typeof(pool.increment("key", delta: 2_u64, initial: 10_u64, expiry: 1_u32)).should eq(UInt64)
    typeof(pool.decrement("key")).should eq(UInt64)
  end

  it "accepts TLS options for pooled clients" do
    endpoint = uninitialized CB::Endpoint
    context = uninitialized OpenSSL::SSL::Context::Client

    typeof(KV::Pool.new(
      endpoint,
      "user",
      "pass",
      "bucket",
      tls_verify: false,
      tls_hostname: "cb.local",
      tls_context: context,
    )).should eq(KV::Pool)
  end

  it "accepts connection strings" do
    context = uninitialized OpenSSL::SSL::Context::Client

    typeof(KV::Pool.from_string(
      "couchbases://user:pass@127.0.0.1:11217/bucket?tls_verify=false&tls_hostname=cb.local",
      size: 2,
      tls_context: context,
    )).should eq(KV::Pool)
  end

  it "accepts explicit credentials with a connection string endpoint" do
    typeof(KV::Pool.from_string(
      "couchbases://127.0.0.1:11217",
      "user",
      "pass",
      "bucket",
      size: 2,
      tls_verify: false,
    )).should eq(KV::Pool)
  end

  it "requires a bucket when it is not passed or embedded" do
    expect_raises(ArgumentError, /bucket/) do
      KV::Pool.from_string("couchbase://user:pass@127.0.0.1")
    end
  end

  it "validates tls_verify query parameters before opening pooled sockets" do
    expect_raises(ArgumentError, /tls_verify/) do
      KV::Pool.from_string("couchbase://user:pass@127.0.0.1/default?tls_verify=nope")
    end
  end
end
