require "../../../../spec_helper"

private alias CB = CryBase::CouchBase
private alias Query = CryBase::CouchBase::Services::Query
private alias QueryHelpers = CryBase::SpecHelpers::QueryHelpers

private def unused_query_port : Int32
  server = TCPServer.new("127.0.0.1", 0)
  server.local_address.port
ensure
  server.try(&.close)
end

describe Query::Cluster do
  it "builds seed endpoints from every connection string host" do
    connection_string = CB::ConnectionString.parse("couchbases://user:pass@n1,n2:18093")

    endpoints = Query::Cluster.seed_endpoints(connection_string)

    endpoints.map(&.host).should eq(["n1", "n2"])
    endpoints.map(&.port).should eq([18093, 18093])
    endpoints.each do |endpoint|
      endpoint.service.should eq(CB::Service::Query)
      endpoint.tls?.should be_true
    end
  end

  it "uses the default Query port when no explicit port is present" do
    connection_string = CB::ConnectionString.parse("couchbase://user:pass@n1,n2")

    endpoints = Query::Cluster.seed_endpoints(connection_string)

    endpoints.map(&.port).should eq([8093, 8093])
  end

  it "uses per-host ports when seed hosts provide them" do
    connection_string = CB::ConnectionString.parse("couchbase://user:pass@n1:19093,n2:29093")

    endpoints = Query::Cluster.seed_endpoints(connection_string)

    endpoints.map(&.host).should eq(["n1", "n2"])
    endpoints.map(&.port).should eq([19093, 29093])
  end

  it "keeps Query seeds on Query ports when built from management URLs" do
    connection_string = CB::ConnectionString.parse("http://user:pass@n1:8091,n2:9091")

    endpoints = Query::Cluster.seed_endpoints(connection_string)
    management_endpoints = Query::Cluster.management_endpoints(connection_string)

    endpoints.map(&.port).should eq([8093, 8093])
    management_endpoints.map(&.port).should eq([8091, 9091])
  end

  it "builds management endpoints from Couchbase seed hosts" do
    connection_string = CB::ConnectionString.parse("couchbase://user:pass@n1:19093,n2:29093")

    endpoints = Query::Cluster.management_endpoints(connection_string)

    endpoints.map(&.host).should eq(["n1", "n2"])
    endpoints.map(&.port).should eq([8091, 8091])
    endpoints.each do |endpoint|
      endpoint.service.should eq(CB::Service::Management)
    end
  end

  it "requires at least one seed endpoint" do
    expect_raises(ArgumentError, /seed endpoint/) do
      Query::Cluster.new([] of CB::Endpoint, "user", "pass")
    end
  end

  it "exposes query operations" do
    cluster = uninitialized Query::Cluster

    typeof(cluster.query("SELECT 1")).should eq(Query::Result)
    typeof(cluster.query("SELECT $1", "value")).should eq(Query::Result)
    typeof(cluster.query("SELECT $name", named_args: {name: "value"})).should eq(Query::Result)
    typeof(cluster.query("SELECT 1", adhoc: false)).should eq(Query::Result)
    typeof(cluster.prepare("SELECT 1")).should eq(Query::PreparedStatement)
    typeof(cluster.execute_prepared("[127.0.0.1:8093]plan")).should eq(Query::Result)
  end

  it "accepts connection strings" do
    context = uninitialized OpenSSL::SSL::Context::Client

    typeof(Query::Cluster.from_string(
      "couchbases://user:pass@127.0.0.1,127.0.0.2:18093?tls_verify=false&tls_hostname=cb.local",
      tls_context: context,
    )).should eq(Query::Cluster)
  end

  it "requires credentials when they are not passed or embedded" do
    expect_raises(ArgumentError, /username/) do
      Query::Cluster.from_string("couchbase://127.0.0.1")
    end
  end

  it "validates tls_verify query parameters before opening seed clients" do
    expect_raises(ArgumentError, /tls_verify/) do
      Query::Cluster.from_string("couchbase://user:pass@127.0.0.1?tls_verify=nope")
    end
  end

  it "fails over to the next seed on transport errors" do
    closed_port = unused_query_port
    server = QueryHelpers.start(%({
      "status":"success",
      "results":[{"one":1}]
    }))
    closed_endpoint = CB::Endpoint.new("127.0.0.1", closed_port, CB::Service::Query, false)
    cluster = Query::Cluster.new(
      [closed_endpoint, server.endpoint],
      "user",
      "pass",
      connect_timeout: 100.milliseconds,
    )

    result = cluster.query("SELECT 1 AS one")

    result.rows.first["one"].as_i.should eq(1)
    cluster.active_endpoint.should eq(server.endpoint)
  ensure
    cluster.try(&.close)
    server.try(&.close)
  end

  it "discovers Query topology from management seeds before querying" do
    query_server = QueryHelpers.start(%({
      "status":"success",
      "results":[{"node":"discovered"}]
    }))
    topology_server = QueryHelpers.start(%({
      "nodesExt":[
        {"hostname":"127.0.0.1","services":{"n1ql":#{query_server.endpoint.port}}}
      ]
    }), 200, CB::Service::Management)
    closed_endpoint = CB::Endpoint.new("127.0.0.1", unused_query_port, CB::Service::Query, false)
    cluster = Query::Cluster.new(
      [closed_endpoint],
      "user",
      "pass",
      connect_timeout: 100.milliseconds,
      management_seeds: [topology_server.endpoint],
      discover_topology: true,
    )

    result = cluster.query("SELECT 1")
    topology_request = topology_server.requests.receive

    topology_request.resource.should eq(Query::TopologyClient::PATH)
    result.rows.first["node"].as_s.should eq("discovered")
    cluster.active_endpoint.should eq(query_server.endpoint)
    cluster.endpoints.should eq([query_server.endpoint])
  ensure
    cluster.try(&.close)
    query_server.try(&.close)
    topology_server.try(&.close)
  end

  it "caches prepared statements across cluster queries" do
    server = QueryHelpers.start_sequence([
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"name":"[127.0.0.1:8093]cluster"}]
      })),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"query_value":"one"}]
      })),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"query_value":"two"}]
      })),
    ])
    cluster = Query::Cluster.new([server.endpoint], "user", "pass")

    first = cluster.query("SELECT $1 AS query_value", "one", adhoc: false)
    second = cluster.query("SELECT $1 AS query_value", "two", adhoc: false)
    prepare_request = server.requests.receive
    first_execute = server.requests.receive
    second_execute = server.requests.receive

    prepare_request.params["statement"].should eq("PREPARE SELECT $1 AS query_value")
    first_execute.params["prepared"].should eq("[127.0.0.1:8093]cluster")
    second_execute.params["prepared"].should eq("[127.0.0.1:8093]cluster")
    first.rows.first["query_value"].as_s.should eq("one")
    second.rows.first["query_value"].as_s.should eq("two")
  ensure
    cluster.try(&.close)
    server.try(&.close)
  end
end
