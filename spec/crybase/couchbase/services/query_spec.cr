require "../../../spec_helper"

private alias Query = CryBase::CouchBase::Query

describe Query do
  it "maps scan consistency values to Query API parameters" do
    Query::ScanConsistency::NotBounded.to_query_param.should eq("not_bounded")
    Query::ScanConsistency::RequestPlus.to_query_param.should eq("request_plus")
    Query::ScanConsistency::StatementPlus.to_query_param.should eq("statement_plus")
  end
end
