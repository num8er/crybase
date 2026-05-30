require "../structs"

module CryBaseExamples
  def self.cluster_connection_string : String
    "#{SCHEME}://#{HOST}"
  end
end
