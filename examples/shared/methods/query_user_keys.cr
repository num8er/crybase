require "../structs"

module CryBaseExamples
  def self.query_user_keys(users : Array(Structs::User)) : Array(String)
    users.map(&.id)
  end
end
