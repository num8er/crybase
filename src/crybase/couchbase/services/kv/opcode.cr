module CryBase::CouchBase::Services::KV
  # Operation codes for the memcached binary protocol commands this
  # client speaks. Values match the Couchbase Server wire protocol
  # specification.
  #
  # ```
  # KV::Opcode::Get.value          # => 0x00
  # KV::Opcode::SelectBucket.value # => 0x89
  # ```
  enum Opcode : UInt8
    Get                    = 0x00
    Set                    = 0x01
    Delete                 = 0x04
    Increment              = 0x05
    Decrement              = 0x06
    Touch                  = 0x1C
    GetAndTouch            = 0x1D
    Hello                  = 0x1F
    SaslAuth               = 0x21
    GetCollectionsManifest = 0xBA
    SelectBucket           = 0x89
  end
end
