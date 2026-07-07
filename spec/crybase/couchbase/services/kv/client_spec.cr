require "../../../../spec_helper"

private alias CB = CryBase::CouchBase
private alias KV = CryBase::CouchBase::Services::KV
private alias KVSpec = CryBase::SpecHelpers::KVHelpers

describe KV::Client do
  it "exposes scoped collection helpers" do
    client = uninitialized KV::Client

    typeof(client.bucket = "bucket").should eq(String)
    typeof(client.vbucket_count).should eq(UInt16)
    typeof(client.vbucket_count = 64_u16).should eq(UInt16)
    typeof(client.scope).should eq(String)
    typeof(client.scope = "ecommerce_shop").should eq(String)
    typeof(client.collection).should eq(String)
    typeof(client.collection = "users").should eq(String)
    typeof(client.scope("ecommerce_shop")).should eq(KV::ScopeContext(KV::Client))
    typeof(client.scope("ecommerce_shop").collection("users")).should eq(KV::CollectionContext(KV::Client))
    typeof(client.collection("users")).should eq(KV::CollectionContext(KV::Client))
    typeof(client.get("key", collection_id: 1_u32)).should eq(Bytes)
    typeof(client.set("key", "value", collection_id: 1_u32)).should eq(UInt64)
    typeof(client.delete("key", collection_id: 1_u32)).should eq(Nil)
  end

  it "accepts TLS constructor options" do
    endpoint = uninitialized CB::Endpoint
    context = uninitialized OpenSSL::SSL::Context::Client

    typeof(KV::Client.new(
      endpoint,
      "user",
      "pass",
      "bucket",
      tls_verify: false,
      tls_hostname: "cb.local",
      tls_context: context,
      vbucket_count: 64_u16,
    )).should eq(KV::Client)
  end

  it "accepts connection strings" do
    context = uninitialized OpenSSL::SSL::Context::Client

    typeof(KV::Client.from_string(
      "couchbases://user:pass@127.0.0.1:11217/bucket?tls_verify=false&tls_hostname=cb.local",
      discover_bucket_config: false,
      tls_context: context,
    )).should eq(KV::Client)
  end

  it "accepts explicit credentials with a connection string endpoint" do
    typeof(KV::Client.from_string(
      "couchbases://127.0.0.1:11217",
      "user",
      "pass",
      "bucket",
      discover_bucket_config: false,
      tls_verify: false,
    )).should eq(KV::Client)
  end

  it "requires credentials when they are not passed or embedded" do
    expect_raises(ArgumentError, /username/) do
      KV::Client.from_string("couchbase://127.0.0.1/default")
    end
  end

  it "requires a password when only username is embedded" do
    expect_raises(ArgumentError, /password/) do
      KV::Client.from_string("couchbase://user@127.0.0.1/default")
    end
  end

  it "validates tls_verify query parameters before opening a socket" do
    expect_raises(ArgumentError, /tls_verify/) do
      KV::Client.from_string("couchbase://user:pass@127.0.0.1/default?tls_verify=nope")
    end
  end

  it "uses the configured vbucket count for document requests" do
    server = KVSpec.start_server(4)
    client = KV::Client.new(server.endpoint, "user", "pass", "bucket", vbucket_count: 64_u16)

    client.increment("User::seq_no", delta: 1_u64, initial: 1_u64).should eq(1_u64)
    3.times { server.requests.receive }
    request = server.requests.receive

    request.opcode.should eq(KV::Opcode::Increment.value)
    request.key.should eq("User::seq_no")
    request.vbucket.should eq(60_u16)
  ensure
    client.try(&.close)
    server.try(&.close)
  end
end
