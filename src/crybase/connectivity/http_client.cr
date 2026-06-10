require "http/client"
require "./host_port"
require "./socket_config"

module CryBase::Connectivity::HTTPClient
  alias Client = ::HTTP::Client

  RECONNECT_ERROR_MESSAGE = "This HTTP::Client cannot be reconnected"

  def self.open(
    host_port : String,
    config : SocketConfig = SocketConfig.new,
    *,
    username : String? = nil,
    password : String? = nil,
  ) : Client
    parsed = CryBase::Connectivity::HostPort.parse(host_port)
    open(parsed.host, parsed.port, config, username: username, password: password)
  end

  def self.open(
    host : String,
    port : Int32,
    config : SocketConfig = SocketConfig.new,
    *,
    username : String? = nil,
    password : String? = nil,
  ) : Client
    io = CryBase::Connectivity.open_socket(host, port, config)
    client = ::HTTP::Client.new(io, host, port)
    apply_basic_auth(client, username, password)
    client
  rescue ex
    io.try(&.close) rescue nil
    raise ex
  end

  def self.reconnect_error?(error : Exception) : Bool
    error.message == RECONNECT_ERROR_MESSAGE
  end

  private def self.apply_basic_auth(
    client : Client,
    username : String?,
    password : String?,
  ) : Nil
    return unless username || password

    raise ArgumentError.new("HTTP basic auth username required") unless username
    raise ArgumentError.new("HTTP basic auth password required") unless password

    client.basic_auth(username, password)
  end
end
