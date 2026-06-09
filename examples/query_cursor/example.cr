require "../shared/methods"

private alias Examples = CryBaseExamples
private alias User = CryBaseExamples::Structs::User
private alias UserRow = CryBaseExamples::Structs::UserRow

kv = Examples.open_kv_client
cluster = Examples.open_query_cluster
users = [] of User

begin
  users = Examples.seed_query_users(kv)
  keys = Examples.query_user_keys(users)
  statement = <<-N1QL
    SELECT META(u).id AS doc_key, u.id, u.type, u.name, u.email, u.active
    FROM #{Examples.n1ql_collection} AS u
    USE KEYS $keys
    WHERE u.type = $type
    ORDER BY u.name
    N1QL

  cursor = cluster.query_cursor(
    statement,
    named_args: {keys: keys, type: "User"},
    query_context: Examples.query_context,
    readonly: true,
  )

  puts "query_cursor users"
  result = cursor.each_as(UserRow) do |row|
    puts "#{row.doc_key} #{row.name} <#{row.email}> active=#{row.active?}"
  end

  puts "status=#{result.status} rows_retained=#{result.rows.size}"
ensure
  Examples.delete_query_users(kv, users)
  kv.close rescue nil
  cluster.close rescue nil
end
