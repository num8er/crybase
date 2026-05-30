class ULID
  ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

  @@last_timestamp_ns = 0_i128

  def self.generate : String
    timestamp_ns = next_timestamp_ns
    timestamp_ms = timestamp_ns // 1_000_000

    encode(timestamp_ms, 10) + encode(timestamp_ns, 16)
  end

  private def self.next_timestamp_ns : Int128
    now = Time.utc.to_unix_ns
    if now <= @@last_timestamp_ns
      now = @@last_timestamp_ns + 1
    end
    @@last_timestamp_ns = now
    now
  end

  private def self.encode(value : Int128, size : Int32) : String
    String.build(size) do |io|
      size.times do |index|
        shift = (size - index - 1) * 5
        encoded = ((value >> shift) & 0x1f).to_i
        io << ALPHABET[encoded]
      end
    end
  end
end
