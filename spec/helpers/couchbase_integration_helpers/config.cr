module CryBase::SpecHelpers::CouchbaseIntegrationHelpers
  record Config,
    host : String,
    seeds : String,
    user : String,
    pass : String,
    bucket : String,
    management_port : Int32,
    kv_port : Int32,
    tls : Bool,
    tls_verify : Bool,
    tls_hostname : String?
end
