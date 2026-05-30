require "../../../../spec_helper"

private alias CB = CryBase::CouchBase
private alias QueryCursor = CryBase::CouchBase::Services::Query
private alias QueryCursorHelpers = CryBase::SpecHelpers::QueryHelpers

private struct QueryCursorRow
  include JSON::Serializable

  getter name : String
  getter? ok : Bool
end

describe QueryCursor::Cursor do
  it "is exposed by client and cluster query_cursor methods" do
    cluster = uninitialized QueryCursor::Cluster
    client = uninitialized QueryCursor::Client

    typeof(client.query_cursor("SELECT name")).should eq(QueryCursor::Cursor)
    typeof(cluster.query_cursor("SELECT name")).should eq(QueryCursor::Cursor)
  end

  it "streams client cursor rows before the response finishes" do
    release = Channel(Nil).new(2)
    server = QueryCursorHelpers.start_stream(
      %({"requestID":"request-1","status":"success","results":[{"ok":true,"name":"airport"},{"ok":),
      %(false,"name":"route"}],"metrics":{"resultCount":2}}),
      release,
    )
    client = QueryCursor::Client.new(server.endpoint, "user", "pass")
    cursor = client.query_cursor(
      "SELECT * FROM rows",
      bucket: "travel-sample",
      scope: "inventory",
      readonly: true,
    )
    rows = Channel(QueryCursorRow).new(2)
    done = Channel(QueryCursor::Result).new(1)
    errors = Channel(Exception).new(1)

    spawn do
      begin
        result = cursor.each_as(QueryCursorRow) do |row|
          rows.send(row)
        end
        done.send(result)
      rescue ex
        errors.send(ex)
      end
    end

    first = select
    when row = rows.receive
      row
    when ex = errors.receive
      raise ex
    when timeout(1.second)
      raise "cursor did not yield before the response completed"
    end

    first.name.should eq("airport")
    first.ok?.should be_true
    cursor.result.should be_nil

    release.send(nil)

    second = rows.receive
    result = done.receive
    request = server.requests.receive

    second.name.should eq("route")
    second.ok?.should be_false
    result.rows.should be_empty
    result.request_id.should eq("request-1")
    result.metrics.try(&.["resultCount"].as_i).should eq(2)
    cursor.result.should eq(result)
    cursor.closed?.should be_true
    request.params["query_context"].should eq("default:`travel-sample`.`inventory`")
    request.params["readonly"].should eq("true")
  ensure
    release.try(&.send(nil))
    client.try(&.close)
    server.try(&.close)
  end

  it "does not consume query cursors more than once" do
    server = QueryCursorHelpers.start(%({
      "status":"success",
      "results":[{"ok":true,"name":"airport"}]
    }))
    client = QueryCursor::Client.new(server.endpoint, "user", "pass")
    cursor = client.query_cursor("SELECT * FROM rows")

    cursor.each { |row| row }

    expect_raises(IO::Error, /already been consumed/) do
      cursor.each { |row| row }
    end
  ensure
    client.try(&.close)
    server.try(&.close)
  end

  it "streams cluster cursors through the active endpoint" do
    server = QueryCursorHelpers.start(%({
      "requestID":"request-1",
      "status":"success",
      "results":[{"ok":true,"name":"airport"},{"ok":false,"name":"route"}],
      "metrics":{"resultCount":2}
    }))
    cluster = QueryCursor::Cluster.new([server.endpoint], "user", "pass")
    cursor = cluster.query_cursor("SELECT name FROM rows", readonly: true)
    rows = [] of QueryCursorRow

    result = cursor.each_as(QueryCursorRow) do |row|
      rows << row
    end
    request = server.requests.receive

    rows.map(&.name).should eq(["airport", "route"])
    result.rows.should be_empty
    result.request_id.should eq("request-1")
    request.params["readonly"].should eq("true")
  ensure
    cluster.try(&.close)
    server.try(&.close)
  end

  it "keeps cluster cursor failover in the cluster path" do
    closed_port = unused_cursor_query_port
    server = QueryCursorHelpers.start(%({
      "status":"success",
      "results":[{"ok":true,"name":"airport"}]
    }))
    closed_endpoint = CB::Endpoint.new("127.0.0.1", closed_port, CB::Service::Query, false)
    cluster = QueryCursor::Cluster.new(
      [closed_endpoint, server.endpoint],
      "user",
      "pass",
      connect_timeout: 100.milliseconds,
    )
    rows = [] of QueryCursorRow

    result = cluster.query_cursor("SELECT name FROM rows").each_as(QueryCursorRow) do |row|
      rows << row
    end

    rows.first.name.should eq("airport")
    result.rows.should be_empty
    cluster.active_endpoint.should eq(server.endpoint)
  ensure
    cluster.try(&.close)
    server.try(&.close)
  end
end

private def unused_cursor_query_port : Int32
  server = TCPServer.new("127.0.0.1", 0)
  server.local_address.port
ensure
  server.try(&.close)
end
