require "socket"
require "uri"

# Top-level namespace for the CryBase database client toolkit.
#
# Each supported database lives in its own sub-namespace under `CryBase`,
# implementing the abstractions defined in `CryBase::Interfaces`.
# Currently shipped backend: `CryBase::CouchBase`.
#
# ```
# require "crybase"
#
# client = CryBase::CouchBase::Client.new("couchbase://localhost")
# client.connect
# ```
module CryBase
end

require "./crybase/version"
require "./crybase/connectivity"
require "./crybase/interfaces"
require "./crybase/couchbase"
