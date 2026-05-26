struct CryBase::Connectivity::HostPort
  getter host : String
  getter port : Int32

  def self.parse(host_port : String) : self
    parts = host_port.split(':')
    raise_invalid(host_port) unless parts.size == 2

    host = parts[0]
    port = parts[1].to_i?
    raise_invalid(host_port) if host.empty?
    raise_invalid(host_port) unless port && port.in?(1..65_535)

    new(host, port)
  end

  def initialize(@host : String, @port : Int32)
  end

  private def self.raise_invalid(host_port : String) : NoReturn
    raise ArgumentError.new("host_port must look like 127.0.0.1:12345, got #{host_port.inspect}")
  end
end
