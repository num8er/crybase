require "../shared/methods"

private alias Examples = CryBaseExamples
private alias User = CryBaseExamples::Structs::User
private alias UserRow = CryBaseExamples::Structs::UserRow

kv = Examples.open_kv_client
client = Examples.open_query_client
users = [] of User

begin
  users = Examples.seed_query_users(kv)
  keys = Examples.query_user_keys(users)
  statement = <<-N1QL
    SELECT META(u).id AS doc_key, u.id, u.type, u.name, u.email, u.active
    FROM #{Examples.n1ql_collection} AS u
    USE KEYS $keys
    WHERE u.type = $type AND u.active = $active
    ORDER BY u.name
    N1QL

  active = client.query_as(
    UserRow,
    statement,
    named_args: {keys: keys, type: "User", active: true},
    query_context: Examples.query_context,
    readonly: true,
  )

  puts "query_as active users"
  active.each do |row|
    puts "#{row.doc_key} #{row.name} <#{row.email}> active=#{row.active?}"
  end

  puts "query_each_as inactive users"
  client.query_each_as(
    UserRow,
    statement,
    named_args: {keys: keys, type: "User", active: false},
    bucket: Examples::BUCKET,
    scope: Examples::QUERY_SCOPE,
    readonly: true,
  ) do |row|
    puts "#{row.doc_key} #{row.name} <#{row.email}> active=#{row.active?}"
  end

  puts "query_cursor active users"
  cursor = client.query_cursor(
    statement,
    named_args: {keys: keys, type: "User", active: true},
    query_context: Examples.query_context,
    readonly: true,
  )
  cursor.each_as(UserRow) do |row|
    puts "#{row.doc_key} #{row.name} <#{row.email}> active=#{row.active?}"
  end
ensure
  Examples.delete_query_users(kv, users)
  kv.close rescue nil
  client.close rescue nil
end
