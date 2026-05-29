require "../../../../spec_helper"
require "base64"

private alias CB = CryBase::CouchBase
private alias Query = CryBase::CouchBase::Services::Query
private alias QueryHelpers = CryBase::SpecHelpers::QueryHelpers

describe Query::TopologyClient do
  it "fetches nodeServices with basic auth and parses Query endpoints" do
    server = QueryHelpers.start(%({
      "nodesExt":[
        {"hostname":"127.0.0.1","services":{"n1ql":18093}}
      ]
    }), 200, CB::Service::Management)
    client = Query::TopologyClient.new(server.endpoint, "user", "pass")

    topology = client.fetch
    request = server.requests.receive

    request.resource.should eq(Query::TopologyClient::PATH)
    request.authorization.should eq("Basic #{Base64.strict_encode("user:pass")}")
    topology.endpoints.first.port.should eq(18093)
  ensure
    server.try(&.close)
  end

  it "raises IO errors for failed topology requests" do
    server = QueryHelpers.start(%({"errors":["nope"]}), 503, CB::Service::Management)
    client = Query::TopologyClient.new(server.endpoint, "user", "pass")

    expect_raises(IO::Error, /503/) do
      client.fetch
    end
  ensure
    server.try(&.close)
  end
end
