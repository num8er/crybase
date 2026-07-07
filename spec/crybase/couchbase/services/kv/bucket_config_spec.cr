require "../../../../spec_helper"

private alias KV = CryBase::CouchBase::Services::KV

describe KV::BucketConfig do
  it "parses top-level numVBuckets" do
    config = KV::BucketConfig.from_json(%({
      "name":"bucket64",
      "numVBuckets":64
    }))

    config.name.should eq("bucket64")
    config.vbucket_count.should eq(64_u16)
  end

  it "accepts string numVBuckets values" do
    config = KV::BucketConfig.from_json(%({"numVBuckets":"128"}))

    config.vbucket_count.should eq(128_u16)
  end

  it "falls back to vBucketServerMap length" do
    config = KV::BucketConfig.from_json(%({
      "vBucketServerMap":{
        "vBucketMap":[[0],[0],[-1]]
      }
    }))

    config.vbucket_count.should eq(3_u16)
  end

  it "requires a positive vbucket count" do
    expect_raises(ArgumentError, /greater than 0/) do
      KV::BucketConfig.from_json(%({"numVBuckets":0}))
    end
  end

  it "requires bucket config vbucket metadata" do
    expect_raises(ArgumentError, /numVBuckets/) do
      KV::BucketConfig.from_json(%({"name":"missing"}))
    end
  end
end
