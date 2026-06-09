require "../../../../spec_helper"

private alias CB = CryBase::CouchBase
private alias Query = CryBase::CouchBase::Services::Query
private alias QueryHelpers = CryBase::SpecHelpers::QueryHelpers

private def run_query_retry_policy_execution_specs? : Bool
  ENV["CRYBASE_RUN_QUERY_RETRY_POLICY_EXECUTION_SPECS"]? == "1"
end

private def pending_query_retry_policy_execution! : Nil
  pending! "retry policy execution is not implemented yet" unless run_query_retry_policy_execution_specs?
end

private def query_retry_policy(
  *,
  max_attempts : Int32 = 3,
  delay : Time::Span = 0.milliseconds,
  max_elapsed : Time::Span? = 1.second,
  retry_query_errors : Bool = true,
  retry_transport_errors : Bool = true,
) : CB::RetryPolicy
  CB::RetryPolicy.new(
    max_attempts: max_attempts,
    delay: delay,
    jitter: 0.0,
    max_elapsed: max_elapsed,
    retry_query_errors: retry_query_errors,
    retry_transport_errors: retry_transport_errors,
  )
end

private def unused_retry_policy_query_port : Int32
  server = TCPServer.new("127.0.0.1", 0)
  server.local_address.port
ensure
  server.try(&.close)
end

describe "Query retry policy execution" do
  it "retries retryable Query errors until success" do
    pending_query_retry_policy_execution!
    server = QueryHelpers.start_sequence([
      QueryHelpers::Response.new(%({
        "status":"errors",
        "errors":[{"code":5000,"msg":"temporary 1"}],
        "results":[]
      }), 503),
      QueryHelpers::Response.new(%({
        "status":"errors",
        "errors":[{"code":5000,"msg":"temporary 2"}],
        "results":[]
      }), 503),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"ok":true}]
      })),
    ])
    client = Query::Client.new(server.endpoint, "user", "pass")

    result = client.query("SELECT true AS ok", retry_policy: query_retry_policy(max_attempts: 3))
    first = server.requests.receive
    second = server.requests.receive
    third = server.requests.receive

    first.params["statement"].should eq("SELECT true AS ok")
    second.params["statement"].should eq("SELECT true AS ok")
    third.params["statement"].should eq("SELECT true AS ok")
    result.rows.first["ok"].as_bool.should be_true
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "does not retry Query errors when retry_query_errors is false" do
    pending_query_retry_policy_execution!
    server = QueryHelpers.start_sequence([
      QueryHelpers::Response.new(%({
        "status":"errors",
        "errors":[{"code":5000,"msg":"temporary"}],
        "results":[]
      }), 503),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"ok":true}]
      })),
    ])
    client = Query::Client.new(server.endpoint, "user", "pass")

    expect_raises(Query::Error, /temporary/) do
      client.query(
        "SELECT true AS ok",
        retry_policy: query_retry_policy(max_attempts: 3, retry_query_errors: false),
      )
    end
    server.requests.receive.params["statement"].should eq("SELECT true AS ok")
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "stops Query-error retries at max_attempts" do
    pending_query_retry_policy_execution!
    server = QueryHelpers.start_sequence([
      QueryHelpers::Response.new(%({
        "status":"errors",
        "errors":[{"code":5000,"msg":"temporary 1"}],
        "results":[]
      }), 503),
      QueryHelpers::Response.new(%({
        "status":"errors",
        "errors":[{"code":5000,"msg":"temporary 2"}],
        "results":[]
      }), 503),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"ok":true}]
      })),
    ])
    client = Query::Client.new(server.endpoint, "user", "pass")

    expect_raises(Query::Error, /temporary 2/) do
      client.query("SELECT true AS ok", retry_policy: query_retry_policy(max_attempts: 2))
    end
    server.requests.receive.params["statement"].should eq("SELECT true AS ok")
    server.requests.receive.params["statement"].should eq("SELECT true AS ok")
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "stops Query-error retries when max_elapsed is exhausted" do
    pending_query_retry_policy_execution!
    server = QueryHelpers.start_sequence([
      QueryHelpers::Response.new(%({
        "status":"errors",
        "errors":[{"code":5000,"msg":"temporary"}],
        "results":[]
      }), 503),
      QueryHelpers::Response.new(%({
        "status":"success",
        "results":[{"ok":true}]
      })),
    ])
    client = Query::Client.new(server.endpoint, "user", "pass")

    expect_raises(Query::Error, /temporary/) do
      client.query(
        "SELECT true AS ok",
        retry_policy: query_retry_policy(
          max_attempts: 3,
          delay: 10.milliseconds,
          max_elapsed: 0.milliseconds,
        ),
      )
    end
    server.requests.receive.params["statement"].should eq("SELECT true AS ok")
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "fails over after transport errors when retry_transport_errors is true" do
    pending_query_retry_policy_execution!
    closed_endpoint = CB::Endpoint.new("127.0.0.1", unused_retry_policy_query_port, CB::Service::Query, false)
    server = QueryHelpers.start(%({
      "status":"success",
      "results":[{"one":1}]
    }))
    cluster = Query::Cluster.new(
      [closed_endpoint, server.endpoint],
      "user",
      "pass",
      connect_timeout: 20.milliseconds,
    )

    result = cluster.query(
      "SELECT 1 AS one",
      retry_policy: query_retry_policy(max_attempts: 2, retry_transport_errors: true),
    )

    server.requests.receive.params["statement"].should eq("SELECT 1 AS one")
    result.rows.first["one"].as_i.should eq(1)
    cluster.active_endpoint.should eq(server.endpoint)
  ensure
    cluster.try(&.close)
    server.try(&.close)
  end

  it "does not fail over after transport errors when retry_transport_errors is false" do
    pending_query_retry_policy_execution!
    closed_endpoint = CB::Endpoint.new("127.0.0.1", unused_retry_policy_query_port, CB::Service::Query, false)
    server = QueryHelpers.start(%({
      "status":"success",
      "results":[{"one":1}]
    }))
    cluster = Query::Cluster.new(
      [closed_endpoint, server.endpoint],
      "user",
      "pass",
      connect_timeout: 20.milliseconds,
    )

    error = expect_raises(Exception) do
      cluster.query(
        "SELECT 1 AS one",
        retry_policy: query_retry_policy(max_attempts: 2, retry_transport_errors: false),
      )
    end

    (
      error.is_a?(IO::Error) ||
        error.is_a?(Socket::Error) ||
        error.is_a?(OpenSSL::SSL::Error)
    ).should be_true
  ensure
    cluster.try(&.close)
    server.try(&.close)
  end
end
