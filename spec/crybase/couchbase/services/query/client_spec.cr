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
