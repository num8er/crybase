require "../structs"
require "../ulid"

module CryBaseExamples
  private def self.random_query_user(random : Random, index : Int32) : Structs::User
    id = "User:#{ULID.generate}"
    first_name = QUERY_USER_FIRST_NAMES[random.rand(QUERY_USER_FIRST_NAMES.size)]
    last_name = QUERY_USER_LAST_NAMES[random.rand(QUERY_USER_LAST_NAMES.size)]
    name = "#{first_name} #{last_name}"
    email_name = "#{first_name}.#{last_name}.#{index}".downcase
    domain = QUERY_USER_DOMAINS[random.rand(QUERY_USER_DOMAINS.size)]
    active = index == 0 || random.rand(2) == 0

    Structs::User.new(id, name, "#{email_name}@#{domain}", active)
  end
end
