require "../structs"

module CryBaseExamples
  private def self.seed_hosts : String
    return SEEDS if SEEDS.includes?(":") || KV_PORT.nil?

    "#{SEEDS}:#{KV_PORT}"
  end
end
