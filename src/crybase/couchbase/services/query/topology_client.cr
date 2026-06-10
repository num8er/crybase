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

  private def open_http_client : CryBase::Connectivity::HTTPClient::Client
    CryBase::Connectivity::HTTPClient.open(
      @endpoint.host,
      @endpoint.port,
      http_config,
      username: @username,
      password: @password,
    )
  end

  private def http_config : CryBase::Connectivity::SocketConfig
    CryBase::Connectivity::SocketConfig.new(
      tls: @endpoint.tls?,
      connect_timeout: @connect_timeout,
      read_timeout: @read_timeout,
      write_timeout: @write_timeout,
      tls_verify: @tls_verify,
      tls_hostname: @tls_hostname,
      tls_context: @tls_context,
    )
  end

  private def request_headers : HTTP::Headers
    HTTP::Headers{
      "Accept"     => "application/json",
      "Connection" => "close",
    }
  end
end
