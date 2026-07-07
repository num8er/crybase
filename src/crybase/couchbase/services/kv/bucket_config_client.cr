class CryBase::CouchBase::Services::KV::BucketConfigClient
  getter endpoint : Endpoint
  getter bucket : String

  def initialize(
    @endpoint : Endpoint,
    @username : String,
    @password : String,
    @bucket : String,
    @connect_timeout : Time::Span = 5.seconds,
    @read_timeout : Time::Span = 5.seconds,
    @write_timeout : Time::Span = 5.seconds,
    *,
    @tls_verify : Bool = true,
    @tls_hostname : String? = nil,
    @tls_context : OpenSSL::SSL::Context::Client? = nil,
  )
    raise ArgumentError.new("kv bucket required") if @bucket.empty?
  end

  def fetch : BucketConfig
    client = open_http_client
    begin
      response = client.get(self.class.path(@bucket), request_headers)
      unless response.success?
        raise IO::Error.new("KV bucket config request failed with HTTP #{response.status_code}")
      end

      BucketConfig.from_json(response.body)
    ensure
      client.close rescue nil
    end
  end

  def self.path(bucket : String) : String
    "/pools/default/buckets/#{URI.encode_path_segment(bucket)}"
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

module CryBase::CouchBase::Services::KV
  def self.management_endpoints(
    connection_string : ConnectionString,
    port_override : Int32? = nil,
  ) : Array(Endpoint)
    management_uri = management_scheme?(connection_string)
    default_port = port_override || Service::Management.default_port(connection_string.tls?)

    connection_string.hosts.map_with_index do |host, index|
      port =
        if port_override
          port_override
        elsif management_uri
          connection_string.ports[index] || default_port
        else
          default_port
        end
      Endpoint.new(host, port, Service::Management, connection_string.tls?)
    end
  end

  def self.management_endpoints(seed_endpoints : Array(Endpoint)) : Array(Endpoint)
    endpoints = [] of Endpoint
    seed_endpoints.each do |endpoint|
      management = Endpoint.new(
        endpoint.host,
        Service::Management.default_port(endpoint.tls?),
        Service::Management,
        endpoint.tls?,
      )
      endpoints << management unless endpoints.includes?(management)
    end
    endpoints
  end

  def self.discover_vbucket_count(
    endpoints : Array(Endpoint),
    username : String,
    password : String,
    bucket : String,
    connect_timeout : Time::Span = 5.seconds,
    *,
    tls_verify : Bool = true,
    tls_hostname : String? = nil,
    tls_context : OpenSSL::SSL::Context::Client? = nil,
  ) : UInt16?
    endpoints.each do |endpoint|
      begin
        return BucketConfigClient.new(
          endpoint,
          username,
          password,
          bucket,
          connect_timeout,
          tls_verify: tls_verify,
          tls_hostname: tls_hostname,
          tls_context: tls_context,
        ).fetch.vbucket_count
      rescue IO::Error | Socket::Error | OpenSSL::SSL::Error | JSON::ParseException | ArgumentError
      end
    end

    nil
  end

  private def self.management_scheme?(connection_string : ConnectionString) : Bool
    connection_string.scheme.in?({"http", "https"})
  end
end
