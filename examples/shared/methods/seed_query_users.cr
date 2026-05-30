require "../structs"
require "./random_query_user"

module CryBaseExamples
  def self.seed_query_users(
    kv : CryBase::CouchBase::KV::Client,
    count : Int32 = 8,
  ) : Array(Structs::User)
    random = Random.new(20_260_529)

    Array(Structs::User).new(count) do |index|
      user = random_query_user(random, index)
      kv.set(user.id, user)
      user
    end
  end
end
