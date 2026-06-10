require "uri"

module CryBase::CouchBase
  # Parses a Couchbase connection string of the form:
  #
  # * `couchbase://host[,host2][:port]`                  — plaintext
  # * `couchbases://host[,host2][:port]`                 — TLS
  # * `couchbase://user:pass@host[:port]/bucket?params`  — credentials/options and default bucket
  # * `http(s)://host[:port]`                            — treated as the Management URL
  #
  # ```
  # cs = CryBase::CouchBase::ConnectionString.parse(
  #   "couchbases://user:pass@n1,n2:11207/default?tls_verify=false"
  # )
  # cs.hosts         # => ["n1", "n2"]
  # cs.tls?          # => true
  # cs.explicit_port # => 11207
  # cs.username      # => "user"
  # cs.bucket        # => "default"
  # ```
  struct ConnectionString < CryBase::Interfaces::ConnectionString
    getter hosts : Array(String)
    getter? tls : Bool
    getter username : String?
    getter password : String?
    getter bucket : String?
    getter params : URI::Params
    getter ports : Array(Int32?)
    getter scheme : String

    # Port explicitly given in the URI, or `nil` when none was supplied.
    # `Endpoint.from_string` uses it for the selected endpoint. The
    # cluster-level `Client` uses it only for the Management endpoint.
    getter explicit_port : Int32?

    def initialize(
      @hosts : Array(String),
      @tls : Bool,
      @explicit_port : Int32? = nil,
      @username : String? = nil,
      @password : String? = nil,
      @bucket : String? = nil,
      @params : URI::Params = URI::Params.new,
      @ports : Array(Int32?) = [] of Int32?,
      @scheme : String = "couchbase",
    )
      raise ArgumentError.new("at least one host required") if @hosts.empty?
      @ports = Array(Int32?).new(@hosts.size, nil) if @ports.empty?
      raise ArgumentError.new("ports must match hosts") unless @ports.size == @hosts.size
    end

    # Parses *input* into a `ConnectionString`.
    #
    # Raises `ArgumentError` if the string is empty or has no host
    # component.
    #
    # ```
    # ConnectionString.parse("localhost")          # plaintext, no port
    # ConnectionString.parse("couchbases://h1,h2") # TLS, two hosts
    # ```
    def self.parse(input : String) : ConnectionString
      raise ArgumentError.new("connection string is empty") if input.empty?

      scheme, authority, path, query = split_uri(input.includes?("://") ? input : "couchbase://#{input}")
      tls = scheme.in?({"couchbases", "https"})

      userinfo, hosts_part = split_userinfo(authority)
      username, password = parse_userinfo(userinfo)
      host_specs = hosts_part.split(',', remove_empty: true).map { |part| parse_host(part.strip) }
      hosts = host_specs.map(&.[0])
      ports = host_specs.map(&.[1])
      raise ArgumentError.new("no hosts parsed from #{input.inspect}") if hosts.empty?

      new(
        hosts,
        tls,
        explicit_port(ports),
        username,
        password,
        parse_bucket(path),
        query ? URI::Params.parse(query) : URI::Params.new,
        ports,
        scheme,
      )
    end

    # Returns the first value for *name* from the connection string query.
    def param(name : String) : String?
      params[name]?
    end

    # Reads a boolean query parameter. Accepted true values are `true` and
    # `1`; accepted false values are `false` and `0`.
    def bool_param(name : String, default : Bool) : Bool
      value = param(name)
      return default unless value

      case value.strip.downcase
      when "1", "true"  then true
      when "0", "false" then false
      else
        raise ArgumentError.new("invalid boolean query parameter #{name}=#{value.inspect}")
      end
    end

    private def self.parse_bucket(path : String?) : String?
      return nil unless path

      bucket = path.starts_with?("/") ? path[1..] : path
      return nil if bucket.empty?

      URI.decode_www_form(bucket)
    end

    private def self.split_uri(input : String) : {String, String, String?, String?}
      scheme_idx = input.index("://") || raise ArgumentError.new("missing URI scheme")
      scheme = input[0...scheme_idx].downcase
      rest = input[(scheme_idx + 3)..]

      parts = rest.split('/', 2)
      authority = parts[0]
      tail = parts[1]?
      if query_idx = authority.index('?')
        return {scheme, authority[0...query_idx], nil, authority[(query_idx + 1)..]}
      end

      return {scheme, authority, nil, nil} unless tail

      tail_parts = tail.split('?', 2)
      path = tail_parts[0]
      query = tail_parts[1]?
      {scheme, authority, path, query}
    end

    private def self.split_userinfo(authority : String) : {String?, String}
      if at = authority.rindex('@')
        {authority[0...at], authority[(at + 1)..]}
      else
        {nil, authority}
      end
    end

    private def self.parse_userinfo(userinfo : String?) : {String?, String?}
      return {nil, nil} unless userinfo

      parts = userinfo.split(':', 2)
      username = parts[0]
      password = parts[1]?
      {URI.decode_www_form(username), password ? URI.decode_www_form(password) : nil}
    end

    private def self.parse_host(host : String) : {String, Int32?}
      if (colon = host.rindex(':')) && (port = host[(colon + 1)..].to_i?)
        return {host[0...colon], port}
      end

      {host, nil}
    end

    private def self.explicit_port(ports : Array(Int32?)) : Int32?
      compact = ports.compact
      return nil if compact.empty?
      return compact.first if compact.all? { |port| port == compact.first }
      return compact.first if compact.size == 1 && ports.last == compact.first

      nil
    end
  end
end
