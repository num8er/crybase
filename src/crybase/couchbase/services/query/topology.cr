struct CryBase::CouchBase::Services::Query::Topology
  getter endpoints : Array(Endpoint)

  def initialize(@endpoints : Array(Endpoint))
  end

  def empty? : Bool
    @endpoints.empty?
  end

  def self.from_node_services(
    body : String,
    tls : Bool,
    network : String? = nil,
  ) : Topology
    json = JSON.parse(body)
    endpoints = [] of Endpoint
    nodes = json["nodesExt"]?.try(&.as_a?) || [] of JSON::Any

    nodes.each do |node|
      endpoint_from_node(node, tls, network).try do |endpoint|
        endpoints << endpoint unless endpoints.includes?(endpoint)
      end
    end

    new(endpoints)
  end

  private def self.endpoint_from_node(
    node : JSON::Any,
    tls : Bool,
    network : String?,
  ) : Endpoint?
    object = node.as_h?
    return nil unless object

    default_services = object["services"]?.try(&.as_h?)
    default_port = query_port(default_services, tls)
    host = object["hostname"]?.try(&.as_s?)
    return nil unless host

    port = default_port
    if network
      if alternate = alternate_address(object, network)
        host = alternate["hostname"]?.try(&.as_s?) || host
        port = query_port(alternate["ports"]?.try(&.as_h?), tls) || port
      end
    end

    return nil unless port

    clean_host = strip_port(host)
    return nil if clean_host.empty?

    Endpoint.new(clean_host, port, Service::Query, tls)
  end

  private def self.alternate_address(
    node : Hash(String, JSON::Any),
    network : String,
  ) : Hash(String, JSON::Any)?
    node["alternateAddresses"]?
      .try(&.as_h?)
      .try(&.[network]?)
      .try(&.as_h?)
  end

  private def self.query_port(
    services : Hash(String, JSON::Any)?,
    tls : Bool,
  ) : Int32?
    return nil unless services

    key = tls ? "n1qlSSL" : "n1ql"
    integer(services[key]?)
  end

  private def self.integer(value : JSON::Any?) : Int32?
    return nil unless value

    value.as_i?.try(&.to_i) || value.as_s?.try(&.to_i?)
  end

  private def self.strip_port(hostname : String) : String
    colon = hostname.rindex(':')
    return hostname unless colon

    suffix = hostname[(colon + 1)..]
    suffix.to_i? ? hostname[0...colon] : hostname
  end
end
