module CryBase::CouchBase::Services::KV::Constants
  # Binary-protocol magic byte indicating an outbound (request) packet.
  REQUEST_MAGIC = 0x80_u8

  # Binary-protocol magic byte indicating an inbound (response) packet.
  RESPONSE_MAGIC = 0x81_u8

  # Fixed-width header size in bytes for both requests and responses.
  HEADER_SIZE = 24

  # User-agent string sent in the HELLO request body.
  AGENT = "crybase"

  # HELLO feature code that opts the connection into bucket selection.
  # Sent during the handshake so the server accepts SELECT_BUCKET.
  FEATURE_SELECT_BUCKET = 0x0008_u16

  # Number of vbuckets in Couchbase buckets.
  VBUCKET_COUNT = 1024_u16

  # Fixed-width extras size for KV expiration operations.
  EXPIRY_EXTRAS_SIZE = 4

  # Fixed-width extras size for KV counter operations.
  COUNTER_EXTRAS_SIZE = 20
end
