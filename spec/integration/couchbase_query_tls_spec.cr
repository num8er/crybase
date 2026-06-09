require "../spec_helper"

private alias QueryTLS = CryBase::CouchBase::Query
private alias TLSCouchbase = CryBase::SpecHelpers::CouchbaseIntegrationHelpers

private struct TLSQueryUser
  include JSON::Serializable

  getter type : String
  getter name : String
  getter score : Int32

  def initialize(@type : String, @name : String, @score : Int32)
  end
end

private struct TLSQueryUserRow
  include JSON::Serializable

  getter doc_key : String
  getter name : String
  getter score : Int32
end

private def with_tls_query_retry(& : -> T) : T forall T
  last_error = nil

  20.times do
    begin
      return yield
    rescue ex : IO::Error | Socket::Error | OpenSSL::SSL::Error | QueryTLS::Error
      last_error = ex
      sleep 1.second
    end
  end

  raise last_error || IO::Error.new("TLS Query service did not become ready")
end

private def tls_upsert_user_statement : String
  <<-N1QL
    UPSERT INTO `_default` (KEY, VALUE)
    VALUES ($doc_key, $doc)
    N1QL
end

private def tls_users_query : String
  <<-N1QL
    SELECT META(u).id AS doc_key,
           u.name AS name,
           u.score AS score
    FROM `_default` AS u
    USE KEYS $keys
    WHERE u.type = $type
    ORDER BY u.score
    N1QL
end

private def tls_delete_users_statement : String
  <<-N1QL
    DELETE FROM `_default` AS u
    USE KEYS $keys
    N1QL
end

describe "Couchbase Query TLS integration" do
  config = TLSCouchbase.config
  client = uninitialized QueryTLS::Client
  cluster = uninitialized QueryTLS::Cluster

  before_all do
    next unless TLSCouchbase.enabled? && config.tls

    client = QueryTLS::Client.from_string(
      TLSCouchbase.query_connection_string(config),
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
    )
    cluster = QueryTLS::Cluster.from_string(
      TLSCouchbase.query_cluster_connection_string(config),
      tls_verify: config.tls_verify,
      tls_hostname: config.tls_hostname,
      discover_topology: false,
    )
  end

  before_each do
    pending! "set COUCHBASE_INTEGRATION=1 to run real Couchbase integration specs" unless TLSCouchbase.enabled?
    pending! "set COUCHBASE_TLS=true to run TLS Query integration specs" unless config.tls
  end

  after_all do
    if TLSCouchbase.enabled? && config.tls
      client.close rescue nil
      cluster.close rescue nil
    end
  end

  it "runs direct and cluster data-backed Query requests over TLS" do
    type = "CryBaseTLSQueryUser"
    prefix = "QueryTLS:#{Time.utc.to_unix_ms}"
    documents = [
      {key: "#{prefix}:ada", doc: TLSQueryUser.new(type, "Ada Lovelace", 10)},
      {key: "#{prefix}:grace", doc: TLSQueryUser.new(type, "Grace Hopper", 20)},
      {key: "#{prefix}:katherine", doc: TLSQueryUser.new(type, "Katherine Johnson", 30)},
    ]
    keys = documents.map(&.[:key])

    begin
      documents.each do |document|
        with_tls_query_retry do
          client.query(
            tls_upsert_user_statement,
            named_args: {doc_key: document[:key], doc: document[:doc]},
            bucket: config.bucket,
            scope: "_default",
          )
        end
      end

      client_rows = with_tls_query_retry do
        client.query_as(
          TLSQueryUserRow,
          tls_users_query,
          named_args: {keys: keys, type: type},
          bucket: config.bucket,
          scope: "_default",
          readonly: true,
        )
      end
      cluster_rows = with_tls_query_retry do
        cluster.query_as(
          TLSQueryUserRow,
          tls_users_query,
          named_args: {keys: keys, type: type},
          bucket: config.bucket,
          scope: "_default",
          readonly: true,
        )
      end

      client.endpoint.tls?.should be_true
      cluster.active_endpoint.try(&.tls?).should be_true
      client_rows.map(&.doc_key).should eq(keys)
      client_rows.map(&.name).should eq(["Ada Lovelace", "Grace Hopper", "Katherine Johnson"])
      client_rows.map(&.score).should eq([10, 20, 30])
      cluster_rows.map(&.doc_key).should eq(client_rows.map(&.doc_key))
      cluster_rows.map(&.name).should eq(client_rows.map(&.name))
      cluster_rows.map(&.score).should eq(client_rows.map(&.score))
    ensure
      unless keys.empty?
        client.query(
          tls_delete_users_statement,
          named_args: {keys: keys},
          bucket: config.bucket,
          scope: "_default",
        ) rescue nil
      end
    end
  end
end
