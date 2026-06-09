require "../spec_helper"
require "../../examples/shared/methods"

private alias CursorKV = CryBase::CouchBase::KV
private alias CursorQuery = CryBase::CouchBase::Query
private alias CursorCouchbase = CryBase::SpecHelpers::CouchbaseIntegrationHelpers
private alias CursorUser = CryBaseExamples::Structs::User

private struct CursorUserRow
  include JSON::Serializable

  getter doc_key : String
  getter id : String
  getter type : String
  getter? active : Bool
end

private def with_cursor_query_retry(& : -> T) : T forall T
  last_error = nil

  20.times do
    begin
      return yield
    rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error | CursorQuery::Error
      last_error = ex
      sleep 1.second
    end
  end

  raise last_error || IO::Error.new("Query service did not become ready")
end

describe "Couchbase Query cursor integration" do
  config = CursorCouchbase.config
  kv = uninitialized CursorKV::Client
  cluster = uninitialized CursorQuery::Cluster

  before_all do
    next unless CursorCouchbase.enabled?

    kv = CursorKV::Client.from_string(
      CursorCouchbase.kv_connection_string(config),
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
    cluster = CursorQuery::Cluster.from_string(
      CursorCouchbase.query_cluster_connection_string(config),
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
  end

  before_each do
    pending! "set COUCHBASE_INTEGRATION=1 to run real Couchbase integration specs" unless CursorCouchbase.enabled?
  end

  after_all do
    if CursorCouchbase.enabled?
      kv.close rescue nil
      cluster.close rescue nil
    end
  end

  it "streams seeded example user documents with query_cursor" do
    users = [] of CursorUser

    begin
      users = CryBaseExamples.seed_query_users(kv)
      keys = CryBaseExamples.query_user_keys(users)
      active_users = users.select(&.active?)
      cursor_rows = [] of CursorUserRow
      cursor_result = with_cursor_query_retry do
        cursor = cluster.query_cursor(
          seeded_cursor_users_query,
          named_args: {keys: keys, type: "User", active: true},
          bucket: config.bucket,
          scope: "_default",
          readonly: true,
        )
        cursor.each_as(CursorUserRow) do |row|
          cursor_rows << row
        end
      end

      cursor_rows.map(&.doc_key).sort!.should eq(active_users.map(&.id).sort!)
      cursor_rows.each(&.active?.should be_true)
      cursor_result.rows.should be_empty
      cursor_result.status.should eq("success")
    ensure
      CryBaseExamples.delete_query_users(kv, users)
    end
  end
end

private def seeded_cursor_users_query : String
  <<-N1QL
    SELECT META(u).id AS doc_key, u.id, u.type, u.active
    FROM `_default` AS u
    USE KEYS $keys
    WHERE u.type = $type AND u.active = $active
    ORDER BY u.id
    N1QL
end
