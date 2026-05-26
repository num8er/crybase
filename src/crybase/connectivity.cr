# Shared transport helpers used by service-specific clients.
#
# `CryBase::Connectivity` owns plaintext TCP and TLS socket construction so
# protocol clients can focus on Couchbase request/response behavior.
module CryBase::Connectivity
end

require "./connectivity/socket_config"
require "./connectivity/host_port"
require "./connectivity/tcp_socket"
require "./connectivity/tls_socket"

module CryBase::Connectivity
  def self.open_socket(
    host_port : String,
    config : SocketConfig = SocketConfig.new,
  ) : IO
    parsed = CryBase::Connectivity::HostPort.parse(host_port)
    open_socket(parsed.host, parsed.port, config)
  end

  def self.open_socket(
    host : String,
    port : Int32,
    config : SocketConfig = SocketConfig.new,
  ) : IO
    return CryBase::Connectivity::TLSSocket.open(host, port, config) if config.tls?

    CryBase::Connectivity::TCPSocket.open(host, port, config)
  end
end
