struct CryBase::CouchBase::Services::KV::BucketConfig
  getter name : String?
  getter vbucket_count : UInt16

  def initialize(@vbucket_count : UInt16, @name : String? = nil)
    raise ArgumentError.new("vbucket count must be greater than 0") if @vbucket_count == 0
  end

  def self.from_json(body : String) : BucketConfig
    json = JSON.parse(body)
    name = json["name"]?.try(&.as_s?)
    new(vbucket_count(json), name)
  end

  private def self.vbucket_count(json : JSON::Any) : UInt16
    if count = integer(json["numVBuckets"]?)
      return checked_count(count)
    end

    if count = json["vBucketServerMap"]?
         .try(&.as_h?)
         .try(&.["vBucketMap"]?)
         .try(&.as_a?)
         .try(&.size)
      return checked_count(count)
    end

    raise ArgumentError.new("bucket config numVBuckets required")
  end

  private def self.integer(value : JSON::Any?) : Int32?
    return nil unless value

    value.as_i?.try(&.to_i) || value.as_s?.try(&.to_i?)
  end

  private def self.checked_count(count : Int32) : UInt16
    raise ArgumentError.new("vbucket count must be greater than 0") if count < 1
    raise ArgumentError.new("vbucket count exceeds UInt16") if count > UInt16::MAX

    count.to_u16
  end
end
