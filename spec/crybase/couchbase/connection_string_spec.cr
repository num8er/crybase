require "../../spec_helper"

private alias ConnectionString = CryBase::CouchBase::ConnectionString

describe ConnectionString do
  it "defaults to plaintext couchbase scheme" do
    cs = ConnectionString.parse("localhost")
    cs.hosts.should eq(["localhost"])
    cs.tls?.should be_false
    cs.explicit_port.should be_nil
    cs.username.should be_nil
    cs.password.should be_nil
    cs.bucket.should be_nil
  end

  it "parses couchbases:// as TLS" do
    cs = ConnectionString.parse("couchbases://node1.example.com")
    cs.tls?.should be_true
  end

  it "parses comma-separated hosts and explicit port" do
    cs = ConnectionString.parse("couchbase://a,b,c:8091")
    cs.hosts.should eq(["a", "b", "c"])
    cs.explicit_port.should eq(8091)
    cs.ports.should eq([nil, nil, 8091])
  end

  it "parses per-host ports for seed lists" do
    cs = ConnectionString.parse("couchbase://a:11231,b:11232,c:11233")

    cs.hosts.should eq(["a", "b", "c"])
    cs.ports.should eq([11231, 11232, 11233])
    cs.explicit_port.should be_nil
  end

  it "parses credentials, bucket, and query parameters" do
    cs = ConnectionString.parse(
      "couchbases://user:p%40ss@node1.example.com:11217/default?tls_verify=false&tls_hostname=cb.local"
    )

    cs.hosts.should eq(["node1.example.com"])
    cs.tls?.should be_true
    cs.explicit_port.should eq(11217)
    cs.username.should eq("user")
    cs.password.should eq("p@ss")
    cs.bucket.should eq("default")
    cs.param("tls_hostname").should eq("cb.local")
    cs.bool_param("tls_verify", true).should be_false
  end

  it "parses username without password" do
    cs = ConnectionString.parse("couchbase://user@node1/default")

    cs.username.should eq("user")
    cs.password.should be_nil
    cs.bucket.should eq("default")
  end

  it "decodes bucket path values" do
    cs = ConnectionString.parse("couchbase://user:pass@node1/my%20bucket")

    cs.bucket.should eq("my bucket")
  end

  it "returns the default for missing boolean query parameters" do
    cs = ConnectionString.parse("couchbase://node1")

    cs.bool_param("tls_verify", true).should be_true
    cs.bool_param("tls_verify", false).should be_false
  end

  it "accepts numeric boolean query parameters" do
    ConnectionString.parse("couchbase://node1?tls_verify=1")
      .bool_param("tls_verify", false).should be_true
    ConnectionString.parse("couchbase://node1?tls_verify=0")
      .bool_param("tls_verify", true).should be_false
  end

  it "rejects invalid boolean query parameters" do
    cs = ConnectionString.parse("couchbase://node1?tls_verify=nope")

    expect_raises(ArgumentError, /tls_verify/) do
      cs.bool_param("tls_verify", true)
    end
  end
end
