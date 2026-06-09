require "openssl"
require "./host_port"
require "./socket_config"
require "./tcp_socket"

module CryBase::Connectivity::TLSSocket
  def self.open(
    host_port : String,
    config : SocketConfig = SocketConfig.new,
  ) : OpenSSL::SSL::Socket::Client
    parsed = CryBase::Connectivity::HostPort.parse(host_port)
    open(parsed.host, parsed.port, config)
  end

  def self.open(
    host : String,
    port : Int32,
    config : SocketConfig = SocketConfig.new,
  ) : OpenSSL::SSL::Socket::Client
    tcp = CryBase::Connectivity::TCPSocket.open(host, port, config)
    open(tcp, host, config)
  end

  def self.open(
    tcp : ::TCPSocket,
    host : String,
    config : SocketConfig = SocketConfig.new,
  ) : OpenSSL::SSL::Socket::Client
    OpenSSL::SSL::Socket::Client.new(
      tcp,
      config.tls_context || default_tls_context(config.tls_verify?),
      sync_close: true,
      hostname: config.tls_hostname || host,
    )
  rescue ex
    tcp.close rescue nil
    raise ex
  end

  private def self.default_tls_context(tls_verify : Bool) : OpenSSL::SSL::Context::Client
    return OpenSSL::SSL::Context::Client.new if tls_verify

    context = OpenSSL::SSL::Context::Client.new
    context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
    context
  end
end
