require "../../../../spec_helper"

private alias Query = CryBase::CouchBase::Services::Query

describe Query::PreparedStatement do
  it "builds prepared statement values from prepare results" do
    result = Query::Result.from_body(%({
      "status":"success",
      "results":[{"name":"[127.0.0.1:8093]plan","encoded_plan":"encoded"}]
    }))

    prepared = Query::PreparedStatement.from_result("SELECT 1", result)

    prepared.statement.should eq("SELECT 1")
    prepared.name.should eq("[127.0.0.1:8093]plan")
    prepared.encoded_plan.should eq("encoded")
  end

  it "rejects prepare results without a prepared name" do
    result = Query::Result.from_body(%({
      "status":"success",
      "results":[{"ok":true}]
    }))

    expect_raises(ArgumentError, /prepared statement name/) do
      Query::PreparedStatement.from_result("SELECT 1", result)
    end
  end
end
