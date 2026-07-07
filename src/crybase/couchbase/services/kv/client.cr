module CryBase::CouchBase::Services::KV
  # Talks the Couchbase memcached binary protocol against a single KV
  # node over plaintext or TLS according to the endpoint. Composed from
  # `RequestWriter`, `ResponseReader`, and `Bucket` mixins.
  #
  # On construct: connects to *endpoint*, performs the TLS handshake when
  # `endpoint.tls?`, sends `HELLO` (advertising
  # `Constants::FEATURE_SELECT_BUCKET`),
  # `SASL_AUTH` (PLAIN), and `SELECT_BUCKET` for *bucket*. Then exposes
  # `get` / `set` / `delete` / `touch` / counter operations against that
  # bucket.
  #
  # ```
  # endpoint = CryBase::CouchBase::Endpoint.new(
  #   "node1", 11210, CryBase::CouchBase::Service::KV, false
  # )
  # kv = KV::Client.new(endpoint, "user", "pass", "default")
  # kv.set("hello", "world")
  # kv.get("hello") # => "world".to_slice
  # kv.delete("hello")
  # kv.close
  # ```
  #
  # For connection strings, use `from_string`:
  #
  # ```
  # kv = KV::Client.from_string("couchbase://user:pass@node1/default")
  # ```
  #
  # Out of scope (deliberate, can be layered on top later):
  # * CAS, flags, durability, observe, and other op modifiers
  # * reconnect / retry
  class Client
    include RequestWriter
    include ResponseReader
    include Bucket

    # The `Endpoint` this client is connected to.
    getter endpoint : Endpoint

    # The bucket selected during the construction handshake.
    getter bucket : String
    getter vbucket_count : UInt16

    getter scope : String
    getter collection : String

    @collection_ids : Hash(Tuple(String, String), UInt32)
    @collections_enabled : Bool
    @socket : IO
    @opaque : UInt32

    # Builds a KV endpoint from *uri*, connects, authenticates, and selects
    # a bucket. The first host in the connection string is used.
    #
    # `username`, `password`, and `bucket` may be passed explicitly or
    # embedded as `couchbase://user:pass@host/bucket`. Query parameters
    # currently supported by this helper: `tls_verify` and `tls_hostname`.
    #
    # ```
    # kv = KV::Client.from_string("couchbases://user:pass@node1:11217/default?tls_verify=false")
    # ```
    def self.from_string(
      uri : String,
      username : String? = nil,
      password : String? = nil,
      bucket : String? = nil,
      connect_timeout : Time::Span = 5.seconds,
      *,
      vbucket_count : UInt16? = nil,
      discover_bucket_config : Bool = true,
      management_port : Int32? = nil,
      tls_verify : Bool? = nil,
      tls_hostname : String? = nil,
      tls_context : OpenSSL::SSL::Context::Client? = nil,
    ) : Client
      connection_string = ConnectionString.parse(uri)
      resolved_username = required(username || connection_string.username, "username")
      resolved_password = required(password || connection_string.password, "password")
      resolved_bucket = required(bucket || connection_string.bucket, "bucket")
      resolved_tls_verify = tls_verify.nil? ? connection_string.bool_param("tls_verify", true) : tls_verify
      resolved_tls_hostname = tls_hostname || connection_string.param("tls_hostname")
      resolved_vbucket_count = vbucket_count || if discover_bucket_config
        CryBase::CouchBase::Services::KV.discover_vbucket_count(
          CryBase::CouchBase::Services::KV.management_endpoints(connection_string, management_port),
          resolved_username,
          resolved_password,
          resolved_bucket,
          connect_timeout,
          tls_verify: resolved_tls_verify,
          tls_hostname: resolved_tls_hostname,
          tls_context: tls_context,
        )
      end

      new(
        Endpoint.from_string(uri, Service::KV),
        resolved_username,
        resolved_password,
        resolved_bucket,
        connect_timeout,
        tls_verify: resolved_tls_verify,
        tls_hostname: resolved_tls_hostname,
        tls_context: tls_context,
        vbucket_count: resolved_vbucket_count || Constants::VBUCKET_COUNT,
      )
    end

    # Connects, optionally performs TLS, then performs HELLO, SASL PLAIN
    # auth, and SELECT_BUCKET, leaving the client ready for KV operations.
    #
    # `tls_verify` and `tls_hostname` apply only when `endpoint.tls?`.
    # Provide `tls_context` to use a custom CA or other OpenSSL settings;
    # when supplied, it is used as-is.
    #
    # Raises:
    # * `IO::Error` / `Socket::Error` — socket connect failed
    # * `OpenSSL::SSL::Error` — TLS handshake or certificate verification failed
    # * `KV::AuthFailed` — SASL auth or bucket selection denied
    # * `KV::Error` — server returned any other non-success status
    #
    # The socket is closed and the exception re-raised if any handshake
    # step fails.
    def initialize(
      @endpoint : Endpoint,
      username : String,
      password : String,
      @bucket : String,
      connect_timeout : Time::Span = 5.seconds,
      *,
      tls_verify : Bool = true,
      tls_hostname : String? = nil,
      tls_context : OpenSSL::SSL::Context::Client? = nil,
      @vbucket_count : UInt16 = Constants::VBUCKET_COUNT,
    )
      validate_vbucket_count(@vbucket_count)
      @socket = open_socket(@endpoint, connect_timeout, tls_verify, tls_hostname, tls_context)
      @opaque = 0_u32
      @scope = Constants::DEFAULT_SCOPE
      @collection = Constants::DEFAULT_COLLECTION
      @collections_enabled = false
      @collection_ids = {} of Tuple(String, String) => UInt32
      begin
        hello
        sasl_auth_plain(username, password)
        use(@bucket)
      rescue ex
        @socket.close rescue nil
        raise ex
      end
    end

    def bucket=(name : String) : String
      raise ArgumentError.new("kv bucket required") if name.empty?

      use(name)
      @bucket = name
      @collection_ids.clear
      name
    end

    def vbucket_count=(count : UInt16) : UInt16
      validate_vbucket_count(count)
      @vbucket_count = count
      count
    end

    def scope=(name : String) : String
      raise ArgumentError.new("kv scope required") if name.empty?

      @scope = name
      name
    end

    def collection=(name : String) : String
      raise ArgumentError.new("kv collection required") if name.empty?

      @collection = name
      name
    end

    def scope(name : String) : ScopeContext(Client)
      ScopeContext.new(self, scope: name)
    end

    def collection(name : String) : CollectionContext(Client)
      CollectionContext.new(self, scope: @scope, collection: name)
    end

    # Fetches the document at *key*. When *expiry* is provided, fetches
    # and updates the document expiration atomically. Raises `NotFound`
    # if absent.
    #
    # ```
    # bytes = kv.get("user:42")
    # JSON.parse(String.new(bytes))
    # ```
    def get(
      key : String,
      expiry : UInt32? = nil,
      *,
      collection_id : UInt32? = nil,
    ) : Bytes
      request_key = request_key(key, operation_collection_id(collection_id))
      resp = if expiry
               call(
                 Opcode::GetAndTouch,
                 key: request_key,
                 extras: CryBase::CouchBase::Services::KV.expiry_extras(expiry),
                 vbucket: vbucket_id(key)
               )
             else
               call(Opcode::Get, key: request_key, vbucket: vbucket_id(key))
             end
      ensure_success!(resp, "GET #{key}")
      resp.value
    end

    # Fetches the document at *key* and decodes it as *type*.
    #
    # Use this for values written with `set` from a type that includes
    # `JSON::Serializable`. `String` and `Bytes` are decoded without JSON.
    # When *expiry* is provided, Couchbase fetches the document and updates
    # its expiration atomically.
    #
    # ```
    # struct Profile
    #   include JSON::Serializable
    #
    #   property name : String
    #   property score : Int32
    # end
    #
    # profile = kv.get_as("user:42", Profile)
    # ```
    def get_as(
      key : String,
      type : T.class,
      expiry : UInt32? = nil,
      *,
      collection_id : UInt32? = nil,
    ) : T forall T
      Serializable.decode(get(key, expiry, collection_id: collection_id), type)
    end

    # Compatibility alias for `get_as(key, type, expiry)`.
    def get(
      key : String,
      type : T.class,
      expiry : UInt32? = nil,
      *,
      collection_id : UInt32? = nil,
    ) : T forall T
      get_as(key, type, expiry, collection_id: collection_id)
    end

    # Stores *value* at *key* with optional *expiry* (seconds, or unix
    # timestamp if greater than 30 days). Returns the new CAS token.
    #
    # ```
    # cas = kv.set("hello", "world")
    # cas = kv.set("hello", "world".to_slice, expiry: 60_u32)
    # ```
    def set(
      key : String,
      value : String | Bytes,
      expiry : UInt32 = 0_u32,
      *,
      collection_id : UInt32? = nil,
    ) : UInt64
      bytes = value.is_a?(String) ? value.to_slice : value
      extras = Bytes.new(8)
      IO::ByteFormat::BigEndian.encode(0_u32, extras[0, 4])
      IO::ByteFormat::BigEndian.encode(expiry, extras[4, 4])
      resp = call(
        Opcode::Set,
        key: request_key(key, operation_collection_id(collection_id)),
        extras: extras,
        value: bytes,
        vbucket: vbucket_id(key)
      )
      ensure_success!(resp, "SET #{key}")
      resp.cas
    end

    # Stores *value* at *key*, encoding `JSON::Serializable` values as JSON
    # and all other non-raw values with `to_s`. Returns the new CAS token.
    #
    # Use `get_as(key, Type)` to load JSON-backed objects back into their
    # original type. `String` and `Bytes` are stored unchanged by the raw
    # overload above.
    #
    # ```
    # struct Profile
    #   include JSON::Serializable
    #
    #   property name : String
    #   property score : Int32
    # end
    #
    # cas = kv.set("user:42", Profile.new("ada", 42))
    # ```
    def set(
      key : String,
      value : T,
      expiry : UInt32 = 0_u32,
      *,
      collection_id : UInt32? = nil,
    ) : UInt64 forall T
      set(key, Serializable.encode(value), expiry, collection_id: collection_id)
    end

    # Deletes the document at *key*. Raises `NotFound` if absent.
    #
    # ```
    # kv.delete("hello")
    # ```
    def delete(key : String, *, collection_id : UInt32? = nil) : Nil
      resp = call(
        Opcode::Delete,
        key: request_key(key, operation_collection_id(collection_id)),
        vbucket: vbucket_id(key)
      )
      ensure_success!(resp, "DELETE #{key}")
    end

    # Updates the document expiration without changing its value.
    # Returns the new CAS token.
    def touch(
      key : String,
      expiry : UInt32,
      *,
      collection_id : UInt32? = nil,
    ) : UInt64
      resp = call(
        Opcode::Touch,
        key: request_key(key, operation_collection_id(collection_id)),
        extras: CryBase::CouchBase::Services::KV.expiry_extras(expiry),
        vbucket: vbucket_id(key)
      )
      ensure_success!(resp, "TOUCH #{key}")
      resp.cas
    end

    # Atomically increments the unsigned integer document at *key* by
    # *delta*. If the key is missing, Couchbase creates it with *initial*
    # and applies *expiry*.
    def increment(
      key : String,
      delta : UInt64 = 1_u64,
      initial : UInt64 = 0_u64,
      expiry : UInt32 = 0_u32,
      *,
      collection_id : UInt32? = nil,
    ) : UInt64
      counter(Opcode::Increment, "INCREMENT", key, delta, initial, expiry, collection_id)
    end

    # Atomically decrements the unsigned integer document at *key* by
    # *delta*. Couchbase counters do not go below zero.
    def decrement(
      key : String,
      delta : UInt64 = 1_u64,
      initial : UInt64 = 0_u64,
      expiry : UInt32 = 0_u32,
      *,
      collection_id : UInt32? = nil,
    ) : UInt64
      counter(Opcode::Decrement, "DECREMENT", key, delta, initial, expiry, collection_id)
    end

    def collection_id(scope : String, collection : String) : UInt32
      raise ArgumentError.new("kv scope required") if scope.empty?
      raise ArgumentError.new("kv collection required") if collection.empty?

      return Constants::DEFAULT_COLLECTION_ID if default_collection?(scope, collection)
      raise Error.new(Status::NotSupported, "COLLECTIONS") unless @collections_enabled

      key = {scope, collection}
      if cached = @collection_ids[key]?
        return cached
      end

      id = load_collection_id(scope, collection)
      @collection_ids[key] = id
      id
    end

    # Closes the underlying socket. Idempotent — safe to call when
    # already closed.
    def close : Nil
      @socket.close
    rescue
      # already closed / mid-shutdown — nothing useful to do
    end

    private def open_socket(
      endpoint : Endpoint,
      connect_timeout : Time::Span,
      tls_verify : Bool,
      tls_hostname : String?,
      tls_context : OpenSSL::SSL::Context::Client?,
    ) : IO
      config = CryBase::Connectivity::SocketConfig.new(
        tls: endpoint.tls?,
        connect_timeout: connect_timeout,
        tls_verify: tls_verify,
        tls_hostname: tls_hostname,
        tls_context: tls_context,
      )
      CryBase::Connectivity.open_socket(
        endpoint.host,
        endpoint.port,
        config,
      )
    end

    private def hello : Nil
      features = Bytes.new(4)
      IO::ByteFormat::BigEndian.encode(Constants::FEATURE_SELECT_BUCKET, features)
      IO::ByteFormat::BigEndian.encode(Constants::FEATURE_COLLECTIONS, features[2, 2])
      resp = call(Opcode::Hello, key: Constants::AGENT, value: features)
      ensure_success!(resp, "HELLO")
      @collections_enabled = feature_enabled?(resp.value, Constants::FEATURE_COLLECTIONS)
    end

    private def sasl_auth_plain(username : String, password : String) : Nil
      payload = String.build do |io|
        io.write_byte(0_u8)
        io << username
        io.write_byte(0_u8)
        io << password
      end
      resp = call(Opcode::SaslAuth, key: "PLAIN", value: payload.to_slice)
      raise AuthFailed.new(resp.status, "SASL PLAIN") unless resp.success?
    end

    private def call(
      opcode : Opcode,
      *,
      key : String | Bytes = "",
      extras : Bytes = Bytes.empty,
      value : Bytes = Bytes.empty,
      cas : UInt64 = 0_u64,
      vbucket : UInt16 = 0_u16,
    ) : Response
      @opaque &+= 1
      write(Request.new(opcode, key, extras, value, cas, @opaque, vbucket))
      read
    end

    private def vbucket_id(key : String) : UInt16
      CryBase::CouchBase::Services::KV.vbucket_id(key, @vbucket_count)
    end

    private def request_key(key : String, collection_id : UInt32?) : String | Bytes
      return key unless @collections_enabled

      CryBase::CouchBase::Services::KV.collection_key(
        collection_id || Constants::DEFAULT_COLLECTION_ID,
        key
      )
    end

    private def feature_enabled?(features : Bytes, feature : UInt16) : Bool
      return false unless features.size % 2 == 0

      offset = 0
      while offset < features.size
        return true if IO::ByteFormat::BigEndian.decode(UInt16, features[offset, 2]) == feature
        offset += 2
      end

      false
    end

    private def counter(
      opcode : Opcode,
      op : String,
      key : String,
      delta : UInt64,
      initial : UInt64,
      expiry : UInt32,
      collection_id : UInt32?,
    ) : UInt64
      resp = call(
        opcode,
        key: request_key(key, operation_collection_id(collection_id)),
        extras: CryBase::CouchBase::Services::KV.counter_extras(delta, initial, expiry),
        vbucket: vbucket_id(key)
      )
      ensure_success!(resp, "#{op} #{key}")
      CryBase::CouchBase::Services::KV.counter_value(resp.value)
    end

    private def default_collection?(scope : String, collection : String) : Bool
      scope == Constants::DEFAULT_SCOPE && collection == Constants::DEFAULT_COLLECTION
    end

    private def operation_collection_id(collection_id : UInt32?) : UInt32?
      return collection_id if collection_id
      return nil if default_collection?(@scope, @collection)

      self.collection_id(@scope, @collection)
    end

    private def load_collection_id(scope : String, collection : String) : UInt32
      resp = call(Opcode::GetCollectionsManifest)
      ensure_success!(resp, "GET_COLLECTIONS_MANIFEST")

      manifest = JSON.parse(String.new(resp.value))
      manifest["scopes"].as_a.each do |scope_json|
        next unless scope_json["name"].as_s == scope

        scope_json["collections"].as_a.each do |collection_json|
          next unless collection_json["name"].as_s == collection

          return collection_uid(collection_json["uid"].as_s)
        end
      end

      raise NotFound.new(Status::KeyNotFound, "COLLECTION #{scope}.#{collection}")
    end

    private def collection_uid(uid : String) : UInt32
      value = uid.starts_with?("0x") ? uid[2..] : uid
      value.to_u32(16)
    rescue ex : ArgumentError
      raise IO::Error.new("invalid collection uid #{uid.inspect}: #{ex.message}")
    end

    private def ensure_success!(resp : Response, op : String) : Nil
      return if resp.success?
      case resp.status
      when .key_not_found?
        raise NotFound.new(resp.status, op)
      when .auth_error?, .auth_continue?
        raise AuthFailed.new(resp.status, op)
      else
        raise Error.new(resp.status, op)
      end
    end

    private def self.required(value : String?, name : String) : String
      value || raise ArgumentError.new("#{name} required")
    end

    private def validate_vbucket_count(count : UInt16) : Nil
      raise ArgumentError.new("vbucket count must be greater than 0") if count == 0
    end
  end
end
