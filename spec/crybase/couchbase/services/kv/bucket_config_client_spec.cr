require "../../../../spec_helper"
require "base64"

private alias CB = CryBase::CouchBase
private alias KV = CryBase::CouchBase::Services::KV
private alias QueryHelpers = CryBase::SpecHelpers::QueryHelpers

describe KV::BucketConfigClient do
  it "fetches bucket config with basic auth" do
    server = QueryHelpers.start(%({
      "name":"bucket64",
      "numVBuckets":64
    }), 200, CB::Service::Management)
    client = KV::BucketConfigClient.new(server.endpoint, "user", "pass", "bucket64")

    config = client.fetch
    request = server.requests.receive

    request.resource.should eq(KV::BucketConfigClient.path("bucket64"))
    request.authorization.should eq("Basic #{Base64.strict_encode("user:pass")}")
    config.vbucket_count.should eq(64_u16)
  ensure
    server.try(&.close)
  end

  it "encodes bucket names as path segments" do
    KV::BucketConfigClient.path("bucket name").should eq("/pools/default/buckets/bucket%20name")
  end

  it "raises IO errors for failed bucket config requests" do
    server = QueryHelpers.start(%({"errors":["nope"]}), 404, CB::Service::Management)
    client = KV::BucketConfigClient.new(server.endpoint, "user", "pass", "missing")

    expect_raises(IO::Error, /404/) do
      client.fetch
    end
  ensure
    server.try(&.close)
  end
end
