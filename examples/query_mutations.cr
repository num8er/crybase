require "./query_users"

kv = CryBaseExamples.open_kv_client
client = CryBaseExamples.open_query_client
cluster = CryBaseExamples.open_query_cluster
users = [] of CryBaseExamples::QueryUser
insert_id = "User:#{ULID.generate}"
upsert_id = "User:#{ULID.generate}"
mutation_ids = [insert_id, upsert_id]

begin
  mutation_ids.each { |id| kv.delete(id) rescue nil }
  users = CryBaseExamples.seed_query_users(kv)
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

  inserted = client.query(
    <<-SQL,
      INSERT INTO #{CryBaseExamples.n1ql_bucket} (KEY, VALUE)
      VALUES ($id, $doc)
      RETURNING META().id AS doc_key, type, name, active
      SQL


    named_args: {id: insert_id, doc: inserted_doc},
  )
  puts "INSERT"
  inserted.rows.each { |row| puts row.to_json }

  updated = client.query(
    <<-SQL,
      UPDATE #{CryBaseExamples.n1ql_bucket} AS u
      USE KEYS $id
      SET u.active = $active
      WHERE u.type = $type
      RETURNING META(u).id AS doc_key, u.id, u.type, u.active
      SQL


    named_args: {id: update_id, type: "User", active: false},
  )
  puts "UPDATE"
  updated.rows.each { |row| puts row.to_json }

  array_updated = client.query(
    <<-SQL,
      UPDATE #{CryBaseExamples.n1ql_bucket} AS u
      USE KEYS $id
      SET u.events = [
        {"name": "signup", "done": false},
        {"name": "welcome", "done": false}
      ]
      WHERE u.type = $type
      RETURNING META(u).id AS doc_key, u.events
      SQL


    named_args: {id: array_update_id, type: "User"},
  )
  puts "SET array field"
  array_updated.rows.each { |row| puts row.to_json }

  loop_updated = client.query(
    <<-SQL,
      UPDATE #{CryBaseExamples.n1ql_bucket} AS u
      USE KEYS $id
      SET event.done = true FOR event IN u.events WHEN event.name = $event END
      WHERE u.type = $type
      RETURNING META(u).id AS doc_key, u.events
      SQL


    named_args: {id: array_update_id, type: "User", event: "welcome"},
  )
  puts "SET ... FOR ... END"
  loop_updated.rows.each { |row| puts row.to_json }

  upserted = cluster.query(
    <<-SQL,
      UPSERT INTO #{CryBaseExamples.n1ql_bucket} (KEY, VALUE)
      VALUES ($id, $doc)
      RETURNING META().id AS doc_key, type, name, active
      SQL


    named_args: {id: upsert_id, doc: upserted_doc},
  )
  puts "UPSERT"
  upserted.rows.each { |row| puts row.to_json }

  deleted = cluster.query(
    <<-SQL,
      DELETE FROM #{CryBaseExamples.n1ql_bucket} AS u
      USE KEYS $ids
      RETURNING META(u).id AS doc_key
      SQL


    named_args: {ids: mutation_ids},
  )
  puts "DELETE"
  deleted.rows.each { |row| puts row.to_json }
ensure
  mutation_ids.each { |id| kv.delete(id) rescue nil }
  CryBaseExamples.delete_query_users(kv, users)
  kv.close rescue nil
  client.close rescue nil
  cluster.close rescue nil
end
