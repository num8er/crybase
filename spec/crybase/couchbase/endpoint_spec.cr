require "../../spec_helper"

private alias Endpoint = CryBase::CouchBase::Endpoint
private alias Service = CryBase::CouchBase::Service

describe Endpoint do
  it "stores host/port/service/tls" do
    ep = Endpoint.new("node1", 11210, Service::KV, false)
    ep.host.should eq("node1")
    ep.port.should eq(11210)
    ep.service.should eq(Service::KV)
    ep.tls?.should be_false
  end

  it "builds a plaintext KV endpoint from a connection string" do
    ep = Endpoint.from_string("couchbase://node1")
    ep.host.should eq("node1")
    ep.port.should eq(11210)
    ep.service.should eq(Service::KV)
    ep.tls?.should be_false
  end

  it "builds a TLS KV endpoint from a connection string" do
    ep = Endpoint.from_string("couchbases://node1")
    ep.host.should eq("node1")
    ep.port.should eq(11207)
    ep.service.should eq(Service::KV)
    ep.tls?.should be_true
  end

  it "honors explicit ports for the selected endpoint" do
    ep = Endpoint.from_string("couchbases://node1:11217")
    ep.port.should eq(11217)
    ep.tls?.should be_true
  end

  it "ignores credentials and bucket when building the endpoint" do
    ep = Endpoint.from_string("couchbases://user:pass@node1:11217/default?tls_verify=false")
    ep.host.should eq("node1")
    ep.port.should eq(11217)
    ep.service.should eq(Service::KV)
    ep.tls?.should be_true
  end

  it "uses the first host from a multi-host connection string" do
    ep = Endpoint.from_string("couchbase://node1,node2")
    ep.host.should eq("node1")
  end

  it "uses the first host port from a per-host seed list" do
    ep = Endpoint.from_string("couchbase://node1:11231,node2:11232")
    ep.host.should eq("node1")
    ep.port.should eq(11231)
  end

  it "defaults http schemes to management endpoints" do
    ep = Endpoint.from_string("https://node1:18091")
    ep.host.should eq("node1")
    ep.port.should eq(18091)
    ep.service.should eq(Service::Management)
    ep.tls?.should be_true
  end

  it "accepts an explicit service" do
    ep = Endpoint.from_string("couchbases://node1", Service::Query)
    ep.port.should eq(18093)
    ep.service.should eq(Service::Query)
    ep.tls?.should be_true
  end

  it "honors explicit ports with an explicit service" do
    ep = Endpoint.from_string("couchbases://node1:19093", Service::Query)
    ep.port.should eq(19093)
    ep.service.should eq(Service::Query)
    ep.tls?.should be_true
  end

  it "renders the couchbase scheme for plaintext KV" do
    ep = Endpoint.new("h", 11210, Service::KV, false)
    ep.scheme.should eq("couchbase")
    ep.address.should eq("couchbase://h:11210")
  end

  it "renders the couchbases scheme for TLS KV" do
    ep = Endpoint.new("h", 11207, Service::KV, true)
    ep.scheme.should eq("couchbases")
    ep.address.should eq("couchbases://h:11207")
  end

  it "renders http for non-KV services" do
    ep = Endpoint.new("h", 8093, Service::Query, false)
    ep.scheme.should eq("http")
    ep.address.should eq("http://h:8093")
  end

  it "renders https for non-KV services with TLS" do
    ep = Endpoint.new("h", 18091, Service::Management, true)
    ep.scheme.should eq("https")
    ep.address.should eq("https://h:18091")
  end

  it "to_s prepends the service display name" do
    ep = Endpoint.new("h", 11210, Service::KV, false)
    ep.to_s.should eq("Data (KV) couchbase://h:11210")
  end
end
