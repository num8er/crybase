require "../shared/methods"

private alias Examples = CryBaseExamples
private alias User = CryBaseExamples::Structs::User

kv = Examples.open_kv_client
client = Examples.open_query_client
cluster = Examples.open_query_cluster
users = [] of User
insert_id = "User:#{ULID.generate}"
upsert_id = "User:#{ULID.generate}"
mutation_ids = [insert_id, upsert_id]

begin
  mutation_ids.each { |id| kv.delete(id) rescue nil }
  users = Examples.seed_query_users(kv)
  update_id = users.first.id
  array_update_id = users[1].id
  inserted_doc = {
    id:     insert_id,
    type:   "User",
    name:   "Inserted User",
    email:  "inserted.user@example.com",
    active: true,
    events: [
      {name: "signup", done: false},
      {name: "welcome", done: false},
    ],
  }
  upserted_doc = {
    id:     upsert_id,
    type:   "User",
    name:   "Upserted User",
    email:  "upserted.user@example.com",
    active: false,
    events: [
      {name: "signup", done: true},
      {name: "welcome", done: false},
    ],
  }
  insert_statement = <<-SQL
    INSERT INTO #{Examples.n1ql_collection} (KEY, VALUE)
    VALUES ($id, $doc)
    RETURNING META().id AS doc_key, type, name, active
    SQL
  update_statement = <<-SQL
    UPDATE #{Examples.n1ql_collection} AS u
    USE KEYS $id
    SET u.active = $active
    WHERE u.type = $type
    RETURNING META(u).id AS doc_key, u.id, u.type, u.active
    SQL
  array_update_statement = <<-SQL
    UPDATE #{Examples.n1ql_collection} AS u
    USE KEYS $id
    SET u.events = [
      {"name": "signup", "done": false},
      {"name": "welcome", "done": false}
    ]
    WHERE u.type = $type
    RETURNING META(u).id AS doc_key, u.events
    SQL
  loop_update_statement = <<-SQL
    UPDATE #{Examples.n1ql_collection} AS u
    USE KEYS $id
    SET event.done = true FOR event IN u.events WHEN event.name = $event END
    WHERE u.type = $type
    RETURNING META(u).id AS doc_key, u.events
    SQL
  upsert_statement = <<-SQL
    UPSERT INTO #{Examples.n1ql_collection} (KEY, VALUE)
    VALUES ($id, $doc)
    RETURNING META().id AS doc_key, type, name, active
    SQL
  delete_statement = <<-SQL
    DELETE FROM #{Examples.n1ql_collection} AS u
    USE KEYS $ids
    RETURNING META(u).id AS doc_key
    SQL

  inserted = client.query(
    insert_statement,
    named_args: {id: insert_id, doc: inserted_doc},
    query_context: Examples.query_context,
  )
  puts "INSERT"
  inserted.rows.each { |row| puts row.to_json }

  updated = client.query(
    update_statement,
    named_args: {id: update_id, type: "User", active: false},
    bucket: Examples::BUCKET,
    scope: Examples::QUERY_SCOPE,
  )
  puts "UPDATE"
  updated.rows.each { |row| puts row.to_json }

  array_updated = client.query(
    array_update_statement,
    named_args: {id: array_update_id, type: "User"},
    query_context: Examples.query_context,
  )
  puts "SET array field"
  array_updated.rows.each { |row| puts row.to_json }

  loop_updated = client.query(
    loop_update_statement,
    named_args: {id: array_update_id, type: "User", event: "welcome"},
    query_context: Examples.query_context,
  )
  puts "SET ... FOR ... END"
  loop_updated.rows.each { |row| puts row.to_json }

  upserted = cluster.query(
    upsert_statement,
    named_args: {id: upsert_id, doc: upserted_doc},
    query_context: Examples.query_context,
  )
  puts "UPSERT"
  upserted.rows.each { |row| puts row.to_json }

  deleted = cluster.query(
    delete_statement,
    named_args: {ids: mutation_ids},
    query_context: Examples.query_context,
  )
  puts "DELETE"
  deleted.rows.each { |row| puts row.to_json }
ensure
  mutation_ids.each { |id| kv.delete(id) rescue nil }
  Examples.delete_query_users(kv, users)
  kv.close rescue nil
  client.close rescue nil
  cluster.close rescue nil
end
