require "openssl"

struct CryBase::Connectivity::SocketConfig
  getter? tls : Bool
  getter connect_timeout : Time::Span
  getter read_timeout : Time::Span?
  getter write_timeout : Time::Span?
  getter? tls_verify : Bool
  getter tls_hostname : String?
  getter tls_context : OpenSSL::SSL::Context::Client?

  def initialize(
    @tls : Bool = false,
    @connect_timeout : Time::Span = 5.seconds,
    @read_timeout : Time::Span? = nil,
    @write_timeout : Time::Span? = nil,
    @tls_verify : Bool = true,
    @tls_hostname : String? = nil,
    @tls_context : OpenSSL::SSL::Context::Client? = nil,
  )
  end
end
