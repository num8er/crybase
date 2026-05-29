require "../spec_helper"

private alias Query = CryBase::CouchBase::Query
private alias Couchbase = CryBase::SpecHelpers::CouchbaseIntegrationHelpers

private def with_query_retry(& : -> T) : T forall T
  last_error = nil

  20.times do
    begin
      return yield
    rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error | Query::Error
      last_error = ex
      sleep 1.second
    end
  end

  raise last_error || IO::Error.new("Query service did not become ready")
end

describe "Couchbase Query integration" do
  config = Couchbase.config
  client = uninitialized Query::Client
  cluster = uninitialized Query::Cluster

  before_all do
    next unless Couchbase.enabled?

    client = Query::Client.from_string(
      Couchbase.query_connection_string(config),
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
    cluster = Query::Cluster.from_string(
      Couchbase.query_cluster_connection_string(config),
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
  end

  before_each do
    pending! "set COUCHBASE_INTEGRATION=1 to run real Couchbase integration specs" unless Couchbase.enabled?
  end

  after_all do
    if Couchbase.enabled?
      client.close rescue nil
      cluster.close rescue nil
    end
  end

  it "runs a parameterized readonly N1QL statement" do
    result = with_query_retry do
      client.query(
        "SELECT $name AS name, $score AS score",
        named_args: {name: "crybase", score: 42},
        readonly: true,
      )
    end

    result.rows.first["name"].as_s.should eq("crybase")
    result.rows.first["score"].as_i.should eq(42)
  end

  it "runs N1QL through a seed-failover cluster" do
    result = with_query_retry do
      cluster.query("SELECT $1 AS value", "cluster", readonly: true)
    end

    result.rows.first["value"].as_s.should eq("cluster")
  end

  it "prepares and executes N1QL statements" do
    prepared = with_query_retry do
      client.prepare("SELECT $name AS name", readonly: true)
    end

    result = with_query_retry do
      client.execute_prepared(prepared, named_args: {name: "prepared"}, readonly: true)
    end

    result.rows.first["name"].as_s.should eq("prepared")
  end

  it "uses prepared statements when adhoc is false" do
    result = with_query_retry do
      cluster.query("SELECT $1 AS value", "cached", readonly: true, adhoc: false)
    end

    result.rows.first["value"].as_s.should eq("cached")
  end
end
