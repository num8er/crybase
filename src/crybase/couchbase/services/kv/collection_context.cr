class CryBase::CouchBase::Services::KV::CollectionContext(Target)
  getter target : Target
  getter scope : String
  getter collection : String
  getter collection_id : UInt32

  def initialize(
    @target : Target,
    *,
    @scope : String,
    @collection : String,
  )
    raise ArgumentError.new("kv scope required") if @scope.empty?
    raise ArgumentError.new("kv collection required") if @collection.empty?

    @collection_id = @target.collection_id(@scope, @collection)
  end

  def get(key : String, expiry : UInt32? = nil) : Bytes
    @target.get(key, expiry, collection_id: @collection_id)
  end

  def get_as(key : String, type : T.class, expiry : UInt32? = nil) : T forall T
    @target.get_as(key, type, expiry, collection_id: @collection_id)
  end

  def get(key : String, type : T.class, expiry : UInt32? = nil) : T forall T
    get_as(key, type, expiry)
  end

  def set(key : String, value : String | Bytes, expiry : UInt32 = 0_u32) : UInt64
    @target.set(key, value, expiry, collection_id: @collection_id)
  end

  def set(key : String, value : T, expiry : UInt32 = 0_u32) : UInt64 forall T
    @target.set(key, value, expiry, collection_id: @collection_id)
  end

  def delete(key : String) : Nil
    @target.delete(key, collection_id: @collection_id)
  end

  def touch(key : String, expiry : UInt32) : UInt64
    @target.touch(key, expiry, collection_id: @collection_id)
  end

  def increment(
    key : String,
    delta : UInt64 = 1_u64,
    initial : UInt64 = 0_u64,
    expiry : UInt32 = 0_u32,
  ) : UInt64
    @target.increment(
      key,
      delta: delta,
      initial: initial,
      expiry: expiry,
      collection_id: @collection_id,
    )
  end

  def decrement(
    key : String,
    delta : UInt64 = 1_u64,
    initial : UInt64 = 0_u64,
    expiry : UInt32 = 0_u32,
  ) : UInt64
    @target.decrement(
      key,
      delta: delta,
      initial: initial,
      expiry: expiry,
      collection_id: @collection_id,
    )
  end
end
