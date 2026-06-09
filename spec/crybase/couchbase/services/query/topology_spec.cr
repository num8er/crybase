require "../../../../spec_helper"

private alias CB = CryBase::CouchBase
private alias Query = CryBase::CouchBase::Services::Query

describe Query::Topology do
  it "parses Query endpoints from nodeServices payloads" do
    topology = Query::Topology.from_node_services(%({
      "nodesExt":[
        {"hostname":"n1","services":{"n1ql":8093}},
        {"hostname":"n2:8091","services":{"n1ql":19093}},
        {"hostname":"data-only","services":{"kv":11210}}
      ]
    }), tls: false)

    topology.endpoints.map(&.host).should eq(["n1", "n2"])
    topology.endpoints.map(&.port).should eq([8093, 19093])
    topology.endpoints.each do |endpoint|
      endpoint.service.should eq(CB::Service::Query)
      endpoint.tls?.should be_false
    end
  end

  it "uses TLS Query ports when TLS is enabled" do
    topology = Query::Topology.from_node_services(%({
      "nodesExt":[
        {"hostname":"n1","services":{"n1ql":8093,"n1qlSSL":18093}}
      ]
    }), tls: true)

    topology.endpoints.first.port.should eq(18093)
    topology.endpoints.first.tls?.should be_true
  end

  it "does not use plaintext Query ports for TLS topology" do
    topology = Query::Topology.from_node_services(%({
      "nodesExt":[
        {"hostname":"n1","services":{"n1ql":8093}}
      ]
    }), tls: true)

    topology.endpoints.should be_empty
  end

  it "uses alternate addresses for a requested network" do
    topology = Query::Topology.from_node_services(%({
      "nodesExt":[
        {
          "hostname":"private",
          "services":{"n1ql":8093},
          "alternateAddresses":{
            "external":{
              "hostname":"public",
              "ports":{"n1ql":19093}
            }
          }
        }
      ]
    }), tls: false, network: "external")

    topology.endpoints.first.host.should eq("public")
    topology.endpoints.first.port.should eq(19093)
  end

  it "removes duplicate Query endpoints" do
    topology = Query::Topology.from_node_services(%({
      "nodesExt":[
        {"hostname":"n1","services":{"n1ql":8093}},
        {"hostname":"n1","services":{"n1ql":8093}}
      ]
    }), tls: false)

    topology.endpoints.size.should eq(1)
  end
end
