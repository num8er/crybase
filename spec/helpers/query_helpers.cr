require "http/server"

module CryBase::SpecHelpers::QueryHelpers
  private alias CB = CryBase::CouchBase

  record Request,
    resource : String,
    params : URI::Params,
    authorization : String?

  record Server,
    endpoint : CB::Endpoint,
    requests : Channel(Request),
    server : HTTP::Server do
    def close : Nil
      server.close
    rescue
    end
  end

  def self.start(response_body : String, status_code : Int32 = 200) : Server
    start(response_body, status_code, CB::Service::Query)
  end

  def self.start(
    response_body : String,
    status_code : Int32,
    service : CB::Service,
  ) : Server
    requests = Channel(Request).new(10)
    server = HTTP::Server.new do |context|
      body = context.request.body.try(&.gets_to_end) || ""
      requests.send(Request.new(
        context.request.resource,
        URI::Params.parse(body),
        context.request.headers["Authorization"]?,
      ))

      context.response.status_code = status_code
      context.response.content_type = "application/json"
      context.response.print response_body
    end
    address = server.bind_tcp("127.0.0.1", 0)
    spawn { server.listen }

    Server.new(
      CB::Endpoint.new("127.0.0.1", address.port, service, false),
      requests,
      server,
    )
  end
end
