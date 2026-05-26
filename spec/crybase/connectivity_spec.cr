require "../spec_helper"

private alias Connectivity = CryBase::Connectivity

describe Connectivity do
  it "wraps socket options in socket config" do
    context = OpenSSL::SSL::Context::Client.new
    config = Connectivity::SocketConfig.new(
      tls: true,
      connect_timeout: 100.milliseconds,
      read_timeout: 200.milliseconds,
      write_timeout: 300.milliseconds,
      tls_verify: false,
      tls_hostname: "cb.local",
      tls_context: context,
    )

    config.tls?.should be_true
    config.connect_timeout.should eq(100.milliseconds)
    config.read_timeout.should eq(200.milliseconds)
    config.write_timeout.should eq(300.milliseconds)
    config.tls_verify?.should be_false
    config.tls_hostname.should eq("cb.local")
    config.tls_context.should eq(context)
  end

  it "parses host-port strings" do
    host_port = Connectivity::HostPort.parse("127.0.0.1:12345")

    host_port.host.should eq("127.0.0.1")
    host_port.port.should eq(12_345)
  end

  it "opens plaintext TCP sockets" do
    server = TCPServer.new("127.0.0.1", 0)
    accepted = Channel(Nil).new
    config = Connectivity::SocketConfig.new(connect_timeout: 100.milliseconds)

    spawn do
      socket = server.accept
      socket.puts "ok"
      socket.close
      accepted.send nil
    end

    socket = Connectivity::TCPSocket.open(
      "127.0.0.1",
      server.local_address.port,
      config,
    )

    socket.gets.should eq("ok")
    accepted.receive
  ensure
    socket.try(&.close)
    server.try(&.close)
  end

  it "opens plaintext TCP sockets from host-port strings" do
    server = TCPServer.new("127.0.0.1", 0)
    accepted = Channel(Nil).new
    config = Connectivity::SocketConfig.new(connect_timeout: 100.milliseconds)

    spawn do
      socket = server.accept
      socket.puts "ok"
      socket.close
      accepted.send nil
    end

    socket = Connectivity::TCPSocket.open(
      "127.0.0.1:#{server.local_address.port}",
      config,
    )

    socket.gets.should eq("ok")
    accepted.receive
  ensure
    socket.try(&.close)
    server.try(&.close)
  end

  it "rejects invalid host-port strings" do
    [
      "127.0.0.1",
      ":1234",
      "127.0.0.1:",
      "127.0.0.1:0",
      "127.0.0.1:65536",
      "127.0.0.1:not-a-port",
      "127.0.0.1:1234:bad",
    ].each do |host_port|
      expect_raises(ArgumentError, /127\.0\.0\.1:12345/) do
        Connectivity::HostPort.parse(host_port)
      end
    end
  end

  it "opens sockets through the shared helper" do
    server = TCPServer.new("127.0.0.1", 0)
    accepted = Channel(Nil).new
    config = Connectivity::SocketConfig.new(connect_timeout: 100.milliseconds)

    spawn do
      socket = server.accept
      socket.puts "ok"
      socket.close
      accepted.send nil
    end

    socket = Connectivity.open_socket(
      "127.0.0.1",
      server.local_address.port,
      config,
    )

    socket.gets.should eq("ok")
    accepted.receive
  ensure
    socket.try(&.close)
    server.try(&.close)
  end

  it "opens sockets through the shared helper from host-port strings" do
    server = TCPServer.new("127.0.0.1", 0)
    accepted = Channel(Nil).new
    config = Connectivity::SocketConfig.new(connect_timeout: 100.milliseconds)

    spawn do
      socket = server.accept
      socket.puts "ok"
      socket.close
      accepted.send nil
    end

    socket = Connectivity.open_socket(
      "127.0.0.1:#{server.local_address.port}",
      config,
    )

    socket.gets.should eq("ok")
    accepted.receive
  ensure
    socket.try(&.close)
    server.try(&.close)
  end

  it "rejects invalid shared helper host-port strings" do
    expect_raises(ArgumentError, /127\.0\.0\.1:12345/) do
      Connectivity.open_socket("127.0.0.1:1234:bad")
    end
  end

  it "accepts TLS construction options" do
    context = OpenSSL::SSL::Context::Client.new
    config = Connectivity::SocketConfig.new(
      tls: true,
      tls_verify: false,
      tls_hostname: "cb.local",
      tls_context: context,
    )

    typeof(Connectivity.open_socket(
      "127.0.0.1",
      18093,
      config,
    )).should eq(IO)

    typeof(Connectivity.open_socket(
      "127.0.0.1:18093",
      config,
    )).should eq(IO)

    typeof(Connectivity::TLSSocket.open(
      "127.0.0.1:18093",
      config,
    )).should eq(OpenSSL::SSL::Socket::Client)
  end
end
