require "socket"
require "./host_port"
require "./socket_config"

module CryBase::Connectivity::TCPSocket
  # Opens a plaintext TCP socket from a `host:port` string.
  #
  # The value must look like `127.0.0.1:12345`.
  #
  # ```
  # socket = CryBase::Connectivity::TCPSocket.open("127.0.0.1:12345")
  # socket.close
  # ```
  def self.open(
    host_port : String,
    config : SocketConfig = SocketConfig.new,
  ) : ::TCPSocket
    parsed = CryBase::Connectivity::HostPort.parse(host_port)
    open(parsed.host, parsed.port, config)
  end

  def self.open(
    host : String,
    port : Int32,
    config : SocketConfig = SocketConfig.new,
  ) : ::TCPSocket
    socket = ::TCPSocket.new(host, port, connect_timeout: config.connect_timeout)
    if read_timeout = config.read_timeout
      socket.read_timeout = read_timeout
    end
    if write_timeout = config.write_timeout
      socket.write_timeout = write_timeout
    end
    socket.sync = false
    socket
  end
end
