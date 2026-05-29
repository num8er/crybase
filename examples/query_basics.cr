require "./query_users"

kv = CryBaseExamples.open_kv_client
client = CryBaseExamples.open_query_client
users = [] of CryBaseExamples::QueryUser

begin
  users = CryBaseExamples.seed_query_users(kv)
  keys = CryBaseExamples.query_user_keys(users)
  result = client.query(
    <<-N1QL,
      SELECT META(u).id AS doc_key, u.id, u.type, u.name, u.email, u.active
      FROM #{CryBaseExamples.n1ql_bucket} AS u
      USE KEYS $keys
      WHERE u.type = $type AND u.active = $active
      ORDER BY u.name
      N1QL


    named_args: {keys: keys, type: "User", active: true},
    readonly: true,
  )

  result.rows.each do |row|
    puts row.to_json
  end
ensure
  CryBaseExamples.delete_query_users(kv, users)
  kv.close rescue nil
  client.close rescue nil
end
