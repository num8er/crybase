require "../spec_helper"
require "../../examples/shared/methods"

private alias KV = CryBase::CouchBase::KV
private alias CB = CryBase::CouchBase
private alias Query = CryBase::CouchBase::Query
private alias Couchbase = CryBase::SpecHelpers::CouchbaseIntegrationHelpers
private alias User = CryBaseExamples::Structs::User

private struct UserRow
  include JSON::Serializable

  getter doc_key : String
  getter id : String
  getter type : String
  getter? active : Bool
end

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
  kv = uninitialized KV::Client
  client = uninitialized Query::Client
  cluster = uninitialized Query::Cluster

  before_all do
    next unless Couchbase.enabled?

    kv = KV::Client.from_string(
      Couchbase.kv_connection_string(config),
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
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
      kv.close rescue nil
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
      cluster.query("SELECT $1 AS query_value", "cluster", readonly: true)
    end

    result.rows.first["query_value"].as_s.should eq("cluster")
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
      cluster.query("SELECT $1 AS query_value", "cached", readonly: true, adhoc: false)
    end

    result.rows.first["query_value"].as_s.should eq("cached")
  end

  it "accepts explicit retry policies on real Query calls" do
    users = [] of User
    policy = CB::RetryPolicy.new(
      max_attempts: 3,
      delay: 10.milliseconds,
      jitter: 0.0,
      max_elapsed: 200.milliseconds,
      retry_query_errors: true,
      retry_transport_errors: true,
    )

    begin
      users = CryBaseExamples.seed_query_users(kv)
      keys = CryBaseExamples.query_user_keys(users)
      active_users = users.select(&.active?)
      inactive_users = users.reject(&.active?)

      client_result = with_query_retry do
        client.query(
          seeded_users_query,
          named_args: {keys: keys, type: "User", active: true},
          readonly: true,
          retry_policy: policy,
        )
      end
      cluster_result = with_query_retry do
        cluster.query(
          seeded_users_query,
          named_args: {keys: keys, type: "User", active: false},
          readonly: true,
          retry_policy: policy,
        )
      end

      client_result.rows.map(&.["id"].as_s).sort!.should eq(active_users.map(&.id).sort!)
      cluster_result.rows.map(&.["id"].as_s).sort!.should eq(inactive_users.map(&.id).sort!)
    ensure
      CryBaseExamples.delete_query_users(kv, users)
    end
  end

  it "queries seeded example user documents" do
    users = [] of User

    begin
      users = CryBaseExamples.seed_query_users(kv)
      keys = CryBaseExamples.query_user_keys(users)
      active_users = users.select(&.active?)

      result = with_query_retry do
        client.query(
          seeded_users_query,
          named_args: {keys: keys, type: "User", active: true},
          readonly: true,
        )
      end

      result.rows.size.should eq(active_users.size)
      row_ids = result.rows.map(&.["id"].as_s).sort!
      active_ids = active_users.map(&.id).sort!
      row_ids.should eq(active_ids)
      result.rows.each do |row|
        row["doc_key"].as_s.starts_with?("User:").should be_true
        row["id"].as_s.should eq(row["doc_key"].as_s)
        row["type"].as_s.should eq("User")
        row["name"].as_s.empty?.should be_false
        row["email"].as_s.should contain("@")
        row["active"].as_bool.should be_true
      end
    ensure
      CryBaseExamples.delete_query_users(kv, users)
    end
  end

  it "prepares and queries seeded example user documents" do
    users = [] of User

    begin
      users = CryBaseExamples.seed_query_users(kv)
      keys = CryBaseExamples.query_user_keys(users)
      inactive_users = users.reject(&.active?)
      prepared = with_query_retry do
        client.prepare(seeded_users_query, readonly: true)
      end

      result = with_query_retry do
        client.execute_prepared(
          prepared,
          named_args: {keys: keys, type: "User", active: false},
          readonly: true,
        )
      end

      result.rows.size.should eq(inactive_users.size)
      row_ids = result.rows.map(&.["id"].as_s).sort!
      inactive_ids = inactive_users.map(&.id).sort!
      row_ids.should eq(inactive_ids)
      result.rows.each do |row|
        row["doc_key"].as_s.starts_with?("User:").should be_true
        row["type"].as_s.should eq("User")
        row["active"].as_bool.should be_false
      end
    ensure
      CryBaseExamples.delete_query_users(kv, users)
    end
  end

  it "maps and streams typed rows with query context" do
    users = [] of User

    begin
      users = CryBaseExamples.seed_query_users(kv)
      keys = CryBaseExamples.query_user_keys(users)
      active_users = users.select(&.active?)

      rows = with_query_retry do
        client.query_as(
          UserRow,
          seeded_context_users_query,
          named_args: {keys: keys, type: "User", active: true},
          bucket: config.bucket,
          scope: "_default",
          readonly: true,
        )
      end
      streamed = [] of UserRow
      result = with_query_retry do
        cluster.query_each_as(
          UserRow,
          seeded_context_users_query,
          named_args: {keys: keys, type: "User", active: true},
          bucket: config.bucket,
          scope: "_default",
          readonly: true,
        ) do |row|
          streamed << row
        end
      end

      rows.map(&.id).sort!.should eq(active_users.map(&.id).sort!)
      streamed.map(&.doc_key).sort!.should eq(active_users.map(&.id).sort!)
      rows.each(&.active?.should be_true)
      streamed.each(&.active?.should be_true)
      result.rows.should be_empty
    ensure
      CryBaseExamples.delete_query_users(kv, users)
    end
  end
end

private def seeded_users_query : String
  <<-N1QL
    SELECT META(u).id AS doc_key, u.id, u.type, u.name, u.email, u.active
    FROM #{CryBaseExamples.n1ql_bucket} AS u
    USE KEYS $keys
    WHERE u.type = $type AND u.active = $active
    ORDER BY u.name
    N1QL
end

private def seeded_context_users_query : String
  <<-N1QL
    SELECT META(u).id AS doc_key, u.id, u.type, u.active
    FROM `_default` AS u
    USE KEYS $keys
    WHERE u.type = $type AND u.active = $active
    ORDER BY u.id
    N1QL
end
