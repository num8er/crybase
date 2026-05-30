require "../structs"

module CryBaseExamples
  private def self.query_seed_hosts : String
    return SEEDS if SEEDS.includes?(":") || QUERY_PORT.nil?

    "#{SEEDS}:#{QUERY_PORT}"
  end
end
