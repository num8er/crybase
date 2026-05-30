require "../../../../spec_helper"

private alias Query = CryBase::CouchBase::Services::Query

describe Query::QueryContext do
  it "formats bucket and scope query contexts" do
    Query::QueryContext.new("travel-sample", "inventory").to_s.should eq(
      "default:`travel-sample`.`inventory`"
    )
  end

  it "escapes identifier backticks" do
    Query::QueryContext.new("bucket`name", "scope`name").to_s.should eq(
      "default:`bucket``name`.`scope``name`"
    )
  end
end
