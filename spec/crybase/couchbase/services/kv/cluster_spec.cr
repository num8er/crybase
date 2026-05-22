require "../../../../spec_helper"

private alias CB = CryBase::CouchBase
private alias KV = CryBase::CouchBase::Services::KV

describe KV::Cluster do
  it "builds seed endpoints from every connection string host" do
    connection_string = CB::ConnectionString.parse("couchbases://user:pass@n1,n2:11217/default")

    endpoints = KV::Cluster.seed_endpoints(connection_string)

    endpoints.map(&.host).should eq(["n1", "n2"])
    endpoints.map(&.port).should eq([11217, 11217])
    endpoints.each do |endpoint|
      endpoint.service.should eq(CB::Service::KV)
      endpoint.tls?.should be_true
    end
  end

  it "uses the default KV port when no explicit port is present" do
    connection_string = CB::ConnectionString.parse("couchbase://user:pass@n1,n2/default")

    endpoints = KV::Cluster.seed_endpoints(connection_string)

    endpoints.map(&.port).should eq([11210, 11210])
  end

  it "uses per-host ports when seed hosts provide them" do
    connection_string = CB::ConnectionString.parse("couchbase://user:pass@n1:11231,n2:11232/default")

    endpoints = KV::Cluster.seed_endpoints(connection_string)

    endpoints.map(&.host).should eq(["n1", "n2"])
    endpoints.map(&.port).should eq([11231, 11232])
  end

  it "requires at least one seed endpoint" do
    expect_raises(ArgumentError, /seed endpoint/) do
      KV::Cluster.new([] of CB::Endpoint, "user", "pass", "bucket")
    end
  end

  it "requires at least one pooled connection per active seed" do
    endpoint = CB::Endpoint.new("127.0.0.1", 11210, CB::Service::KV, false)

    expect_raises(ArgumentError, /pool size/) do
      KV::Cluster.new([endpoint], "user", "pass", "bucket", size: 0)
    end
  end

  it "exposes delegated client operations" do
    cluster = uninitialized KV::Cluster

    typeof(cluster.get("key")).should eq(Bytes)
    typeof(cluster.get("key", expiry: 1_u32)).should eq(Bytes)
    typeof(cluster.get_as("key", String)).should eq(String)
    typeof(cluster.get("key", String)).should eq(String)
    typeof(cluster.set("key", "value")).should eq(UInt64)
    typeof(cluster.set("key", "value", expiry: 1_u32)).should eq(UInt64)
    typeof(cluster.delete("key")).should eq(Nil)
    typeof(cluster.touch("key", 1_u32)).should eq(UInt64)
    typeof(cluster.increment("key")).should eq(UInt64)
    typeof(cluster.increment("key", delta: 2_u64, initial: 10_u64, expiry: 1_u32)).should eq(UInt64)
    typeof(cluster.decrement("key")).should eq(UInt64)
  end

  it "accepts connection strings" do
    context = uninitialized OpenSSL::SSL::Context::Client

    typeof(KV::Cluster.from_string(
      "couchbases://user:pass@127.0.0.1,127.0.0.2:11217/bucket?tls_verify=false&tls_hostname=cb.local",
      size: 2,
      tls_context: context,
    )).should eq(KV::Cluster)
  end

  it "requires credentials when they are not passed or embedded" do
    expect_raises(ArgumentError, /username/) do
      KV::Cluster.from_string("couchbase://127.0.0.1/default")
    end
  end

  it "validates tls_verify query parameters before opening seed pools" do
    expect_raises(ArgumentError, /tls_verify/) do
      KV::Cluster.from_string("couchbase://user:pass@127.0.0.1/default?tls_verify=nope")
    end
  end
end
