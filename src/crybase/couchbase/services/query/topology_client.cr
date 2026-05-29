class CryBase::CouchBase::Services::Query::TopologyClient
  PATH = "/pools/default/nodeServices"

  getter endpoint : Endpoint

  def initialize(
    @endpoint : Endpoint,
    @username : String,
    @password : String,
    @connect_timeout : Time::Span = Client::DEFAULT_CONNECT_TIMEOUT,
    @read_timeout : Time::Span = Client::DEFAULT_READ_TIMEOUT,
    @write_timeout : Time::Span = Client::DEFAULT_WRITE_TIMEOUT,
    *,
    @tls_verify : Bool = true,
    @tls_hostname : String? = nil,
    @tls_context : OpenSSL::SSL::Context::Client? = nil,
    @network : String? = nil,
  )
  end

  def fetch : Topology
    client = open_http_client
    begin
      response = client.get(PATH, request_headers)
      unless response.success?
        raise IO::Error.new("Query topology request failed with HTTP #{response.status_code}")
      end

      Topology.from_node_services(response.body, @endpoint.tls?, @network)
    ensure
      client.close rescue nil
    end
  end

  private def open_http_client : HTTP::Client
    io = open_io
    client = HTTP::Client.new(io, @endpoint.host, @endpoint.port)
    client.basic_auth(@username, @password)
    client
  end

  private def open_io : IO
    config = CryBase::Connectivity::SocketConfig.new(
      tls: @endpoint.tls?,
      connect_timeout: @connect_timeout,
      read_timeout: @read_timeout,
      write_timeout: @write_timeout,
      tls_verify: @tls_verify,
      tls_hostname: @tls_hostname,
      tls_context: @tls_context,
    )
    CryBase::Connectivity.open_socket(
      @endpoint.host,
      @endpoint.port,
      config,
    )
  end

  private def request_headers : HTTP::Headers
    HTTP::Headers{
      "Accept"     => "application/json",
      "Connection" => "close",
    }
  end
end
