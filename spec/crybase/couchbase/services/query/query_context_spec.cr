require "../../../../spec_helper"

private alias Query = CryBase::CouchBase::Services::Query

describe Query::QueryContext do
  it "formats bucket and scope query contexts" do
    Query::QueryContext.new(bucket: "commerce", scope: "ecommerce_shop").to_s.should eq(
      "default:`commerce`.`ecommerce_shop`"
    )
  end

  it "allows an explicit namespace" do
    Query::QueryContext.new(bucket: "commerce", scope: "ecommerce_shop", namespace: "tenant").to_s.should eq(
      "tenant:`commerce`.`ecommerce_shop`"
    )
  end

  it "escapes identifier backticks" do
    Query::QueryContext.new(bucket: "bucket`name", scope: "scope`name").to_s.should eq(
      "default:`bucket``name`.`scope``name`"
    )
  end
end
