require "../../../../spec_helper"

private alias KV = CryBase::CouchBase::Services::KV

private class RecordingKVTarget
  getter resolved_scope : String?
  getter resolved_collection : String?
  getter last_key : String?
  getter last_collection_id : UInt32?
  getter last_expiry : UInt32?

  def collection_id(scope : String, collection : String) : UInt32
    @resolved_scope = scope
    @resolved_collection = collection
    300_u32
  end

  def get(key : String, expiry : UInt32? = nil, *, collection_id : UInt32? = nil) : Bytes
    record(key, expiry, collection_id)
    "value".to_slice
  end

  def get_as(
    key : String,
    type : T.class,
    expiry : UInt32? = nil,
    *,
    collection_id : UInt32? = nil,
  ) : T forall T
    record(key, expiry, collection_id)
    "value".as(T)
  end

  def get(
    key : String,
    type : T.class,
    expiry : UInt32? = nil,
    *,
    collection_id : UInt32? = nil,
  ) : T forall T
    get_as(key, type, expiry, collection_id: collection_id)
  end

  def set(
    key : String,
    value : String | Bytes,
    expiry : UInt32 = 0_u32,
    *,
    collection_id : UInt32? = nil,
  ) : UInt64
    record(key, expiry, collection_id)
    42_u64
  end

  def set(
    key : String,
    value : T,
    expiry : UInt32 = 0_u32,
    *,
    collection_id : UInt32? = nil,
  ) : UInt64 forall T
    record(key, expiry, collection_id)
    42_u64
  end

  def delete(key : String, *, collection_id : UInt32? = nil) : Nil
    record(key, nil, collection_id)
  end

  def touch(key : String, expiry : UInt32, *, collection_id : UInt32? = nil) : UInt64
    record(key, expiry, collection_id)
    42_u64
  end

  def increment(
    key : String,
    delta : UInt64 = 1_u64,
    initial : UInt64 = 0_u64,
    expiry : UInt32 = 0_u32,
    *,
    collection_id : UInt32? = nil,
  ) : UInt64
    record(key, expiry, collection_id)
    42_u64
  end

  def decrement(
    key : String,
    delta : UInt64 = 1_u64,
    initial : UInt64 = 0_u64,
    expiry : UInt32 = 0_u32,
    *,
    collection_id : UInt32? = nil,
  ) : UInt64
    record(key, expiry, collection_id)
    42_u64
  end

  private def record(key : String, expiry : UInt32?, collection_id : UInt32?) : Nil
    @last_key = key
    @last_expiry = expiry
    @last_collection_id = collection_id
  end
end

describe KV::ScopeContext do
  it "builds collection contexts through scope names" do
    target = RecordingKVTarget.new

    scoped = KV::ScopeContext.new(target, scope: "ecommerce_shop").collection("users")

    scoped.scope.should eq("ecommerce_shop")
    scoped.collection.should eq("users")
    scoped.collection_id.should eq(300_u32)
    target.resolved_scope.should eq("ecommerce_shop")
    target.resolved_collection.should eq("users")
  end

  it "rejects empty scope and collection names" do
    target = RecordingKVTarget.new

    expect_raises(ArgumentError, /scope/) do
      KV::ScopeContext.new(target, scope: "")
    end

    expect_raises(ArgumentError, /collection/) do
      KV::ScopeContext.new(target, scope: "ecommerce_shop").collection("")
    end
  end
end

describe KV::CollectionContext do
  it "delegates operations with a resolved collection id" do
    target = RecordingKVTarget.new
    collection = KV::ScopeContext.new(target, scope: "ecommerce_shop").collection("users")

    collection.get("user:1", expiry: 10_u32).should eq("value".to_slice)
    target.last_key.should eq("user:1")
    target.last_expiry.should eq(10_u32)
    target.last_collection_id.should eq(300_u32)

    collection.set("user:1", "Ada", expiry: 20_u32).should eq(42_u64)
    target.last_key.should eq("user:1")
    target.last_expiry.should eq(20_u32)
    target.last_collection_id.should eq(300_u32)
  end
end
