require "../../../../spec_helper"
require "base64"

private alias CB = CryBase::CouchBase
private alias Query = CryBase::CouchBase::Services::Query
private alias QueryHelpers = CryBase::SpecHelpers::QueryHelpers

describe Query::Client do
  it "accepts connection strings" do
    context = uninitialized OpenSSL::SSL::Context::Client

    client = Query::Client.from_string(
      "couchbases://user:pass@127.0.0.1:18093?tls_verify=false&tls_hostname=cb.local",
      tls_context: context,
    )

    client.endpoint.service.should eq(CB::Service::Query)
    client.endpoint.port.should eq(18093)
    client.endpoint.tls?.should be_true
  end

  it "accepts explicit credentials with a connection string endpoint" do
    client = Query::Client.from_string("couchbase://127.0.0.1:8093", "user", "pass")

    client.endpoint.service.should eq(CB::Service::Query)
  end

  it "requires credentials when they are not passed or embedded" do
    expect_raises(ArgumentError, /username/) do
      Query::Client.from_string("couchbase://127.0.0.1")
    end
  end

  it "requires a password when only username is embedded" do
    expect_raises(ArgumentError, /password/) do
      Query::Client.from_string("couchbase://user@127.0.0.1")
    end
  end

  it "validates tls_verify query parameters before opening a socket" do
    expect_raises(ArgumentError, /tls_verify/) do
      Query::Client.from_string("couchbase://user:pass@127.0.0.1?tls_verify=nope")
    end
  end

  it "posts N1QL form requests and parses rows" do
    server = QueryHelpers.start(%({
      "requestID":"request-1",
      "clientContextID":"ctx-1",
      "status":"success",
      "results":[{"ok":true,"name":"airport"}],
      "metrics":{"resultCount":1}
    }))
    client = Query::Client.new(server.endpoint, "user", "pass")

    result = client.query(
      "SELECT $1 AS kind, $type AS type",
      "airport",
      named_args: {type: "route"},
      readonly: true,
      scan_consistency: Query::ScanConsistency::RequestPlus,
      client_context_id: "ctx-1",
      timeout: 2.seconds,
      options: {metrics: true},
    )
    request = server.requests.receive

    request.resource.should eq(Query::Client::PATH)
    request.authorization.should eq("Basic #{Base64.strict_encode("user:pass")}")
    request.params["statement"].should eq("SELECT $1 AS kind, $type AS type")
    request.params["args"].should eq(%(["airport"]))
    request.params["$type"].should eq(%("route"))
    request.params["readonly"].should eq("true")
    request.params["scan_consistency"].should eq("request_plus")
    request.params["client_context_id"].should eq("ctx-1")
    request.params["timeout"].should eq("2000ms")
    request.params["metrics"].should eq("true")
    result.request_id.should eq("request-1")
    result.client_context_id.should eq("ctx-1")
    result.rows.first["ok"].as_bool.should be_true
    result.rows.first["name"].as_s.should eq("airport")
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "prepares statements" do
    server = QueryHelpers.start(%({
      "status":"success",
      "results":[{"name":"[127.0.0.1:8093]plan","encoded_plan":"encoded"}]
    }))
    client = Query::Client.new(server.endpoint, "user", "pass")

    prepared = client.prepare(
      "SELECT $name AS name",
      "plan",
      options: {query_context: "default:`travel-sample`.inventory"},
    )
    request = server.requests.receive

    request.params["statement"].should eq(
      "PREPARE plan AS SELECT $name AS name"
    )
    request.params["query_context"].should eq("default:`travel-sample`.inventory")
    prepared.statement.should eq("SELECT $name AS name")
    prepared.name.should eq("[127.0.0.1:8093]plan")
    prepared.encoded_plan.should eq("encoded")
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "executes prepared statements with parameters" do
    server = QueryHelpers.start(%({
      "status":"success",
      "results":[{"name":"crybase"}]
    }))
    client = Query::Client.new(server.endpoint, "user", "pass")
    prepared = Query::PreparedStatement.new(
      "SELECT $name AS name",
      "[127.0.0.1:8093]plan",
      nil,
      JSON.parse(%({"name":"[127.0.0.1:8093]plan"})),
    )

    result = client.execute_prepared(
      prepared,
      named_args: {name: "crybase"},
      readonly: true,
    )
    request = server.requests.receive

    request.params["prepared"].should eq("[127.0.0.1:8093]plan")
    request.params.has_key?("statement").should be_false
    request.params["$name"].should eq(%("crybase"))
    request.params["readonly"].should eq("true")
    result.rows.first["name"].as_s.should eq("crybase")
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "uses a cached prepared statement when adhoc is false" do
    server = QueryHelpers.start_sequence([
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"name":"[127.0.0.1:8093]cached"}]
      })),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"value":"first"}]
      })),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"value":"second"}]
      })),
    ])
    client = Query::Client.new(server.endpoint, "user", "pass")

    first = client.query("SELECT $1 AS value", "first", adhoc: false)
    second = client.query("SELECT $1 AS value", "second", adhoc: false)
    prepare_request = server.requests.receive
    first_execute = server.requests.receive
    second_execute = server.requests.receive

    prepare_request.params["statement"].should eq("PREPARE SELECT $1 AS value")
    first_execute.params["prepared"].should eq("[127.0.0.1:8093]cached")
    first_execute.params["args"].should eq(%(["first"]))
    second_execute.params["prepared"].should eq("[127.0.0.1:8093]cached")
    second_execute.params["args"].should eq(%(["second"]))
    first.rows.first["value"].as_s.should eq("first")
    second.rows.first["value"].as_s.should eq("second")
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "reprepares cached statements when the plan is missing" do
    server = QueryHelpers.start_sequence([
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"name":"[127.0.0.1:8093]old"}]
      })),
      QueryHelpers::Response.new(%({
        "status":"errors",
        "errors":[{"code":4040,"msg":"No such prepared statement"}],
        "results":[]
      })),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"name":"[127.0.0.1:8093]new"}]
      })),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"value":"fresh"}]
      })),
    ])
    client = Query::Client.new(server.endpoint, "user", "pass")

    result = client.query("SELECT $1 AS value", "fresh", adhoc: false)
    first_prepare = server.requests.receive
    failed_execute = server.requests.receive
    second_prepare = server.requests.receive
    final_execute = server.requests.receive

    first_prepare.params["statement"].should eq("PREPARE SELECT $1 AS value")
    failed_execute.params["prepared"].should eq("[127.0.0.1:8093]old")
    second_prepare.params["statement"].should eq("PREPARE FORCE SELECT $1 AS value")
    final_execute.params["prepared"].should eq("[127.0.0.1:8093]new")
    result.rows.first["value"].as_s.should eq("fresh")
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "raises Query errors from response payloads" do
    server = QueryHelpers.start(%({
      "status":"errors",
      "errors":[{"code":3000,"msg":"syntax error"}],
      "results":[]
    }))
    client = Query::Client.new(server.endpoint, "user", "pass")

    error = expect_raises(Query::Error, /3000: syntax error/) do
      client.query("SELECT")
    end

    error.status_code.should eq(200)
    error.result.errors.first.code.should eq(3000)
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "can return error results without raising" do
    server = QueryHelpers.start(%({
      "status":"errors",
      "errors":[{"code":4000,"msg":"bad request"}],
      "results":[]
    }), status_code: 400)
    client = Query::Client.new(server.endpoint, "user", "pass")

    result = client.query("SELECT", raise_on_error: false)

    result.error?.should be_true
    result.errors.first.message.should eq("bad request")
  ensure
    client.try(&.close)
    server.try(&.close)
  end
end
