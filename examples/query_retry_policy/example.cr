require "../shared/methods"

private alias Examples = CryBaseExamples
private alias Query = CryBase::CouchBase::Query
private alias RetryPolicy = CryBase::CouchBase::RetryPolicy
private alias User = CryBaseExamples::Structs::User
private alias UserRow = CryBaseExamples::Structs::UserRow

kv = Examples.open_kv_client
client = Examples.open_query_client
cluster = Examples.open_query_cluster
users = [] of User
policy = RetryPolicy.new(
  max_attempts: 3,
  delay: 50.milliseconds,
  jitter: 0.2,
  max_elapsed: 500.milliseconds,
  retry_query_errors: true,
  retry_transport_errors: true,
)
statement = <<-N1QL
  SELECT META(u).id AS doc_key, u.id, u.type, u.name, u.email, u.active
  FROM #{Examples.n1ql_collection} AS u
  USE KEYS $keys
  WHERE u.type = $type AND u.active = $active
  ORDER BY u.name
  N1QL

begin
  users = Examples.seed_query_users(kv)
  keys = Examples.query_user_keys(users)

  client_result = client.query(
    statement,
    named_args: {
      keys:   keys,
      type:   "User",
      active: true,
    },
    query_context: Examples.query_context,
    readonly: true,
    retry_policy: policy,
  )
  puts "client query active users"
  client_result.each_row_as(UserRow) do |row|
    puts "#{row.doc_key} #{row.name} <#{row.email}> active=#{row.active?}"
  end

  cluster_result = cluster.query(
    statement,
    named_args: {
      keys:   keys,
      type:   "User",
      active: false,
    },
    query_context: Examples.query_context,
    readonly: true,
    retry_policy: policy,
  )
  puts "cluster query inactive users"
  cluster_result.each_row_as(UserRow) do |row|
    puts "#{row.doc_key} #{row.name} <#{row.email}> active=#{row.active?}"
  end
ensure
  Examples.delete_query_users(kv, users)
  kv.close rescue nil
  client.close rescue nil
  cluster.close rescue nil
end
