enum CryBase::CouchBase::Services::Query::ScanConsistency
  NotBounded
  RequestPlus
  StatementPlus

  def to_query_param : String
    case self
    in NotBounded    then "not_bounded"
    in RequestPlus   then "request_plus"
    in StatementPlus then "statement_plus"
    end
  end
end
