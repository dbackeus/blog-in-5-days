require 'socket'
require "zlib"

require_relative "forked_web_server"
require_relative "threaded_web_server"

class Request
  CARRIAGE_RETURN = "\r\n"

  def self.from_socket(socket)
    first_line = socket.gets
    return unless first_line # client is done requesting over the keep alive connection

    method, path, http_version = first_line.split(" ")
    content_length = nil
    headers = {}
    while (line = socket.gets) && (line != CARRIAGE_RETURN)
      key, value = line.split(":")
      headers[key.strip.downcase] = value.strip
    end
    if content_length = headers["content-length"]
      body = socket.readpartial(content_length.to_i)
    end

    new(method: method, path: path, headers: headers, body: body)
  end

  attr_reader :method, :path, :headers, :body
  attr_accessor :route_match

  def initialize(method:, path:, headers:, body:)
    @method = method
    @path = path
    @headers = headers
    @body = body
  end
end

STATIC_VIEWS = Dir.glob("app/views/*").each_with_object({}) do |path, hash|
  view = File.read(path)
  hash[File.basename(path)] = view
  hash["#{File.basename(path)}.deflated"] = Zlib::Deflate.deflate(view)
end

routes = {
  "GET" => {
    %r{/$} => lambda do |request|
      [200, STATIC_VIEWS.fetch("index.html.deflated")]
    end,
    %r{/large/?$} => lambda do |request|
      [200, STATIC_VIEWS.fetch("large.html.deflated")]
    end,
    %r{/posts/?$} => lambda do |request|
      [200, STATIC_VIEWS.fetch("posts.html.deflated")]
    end,
    %r{/posts/new$} => lambda do |request|
      [200, STATIC_VIEWS.fetch("posts_new.html.deflated")]
    end,
  },
  "POST" => {
    %r{/posts/?$} => lambda do |request|
      puts request.body
      [404, STATIC_VIEWS.fetch("404.html.deflated")]
    end,
  }
}

def respond(socket, body: "", status: 200)
  socket.print(
    "HTTP/1.1 #{status}\r\n" \
    "Content-Type: text/html\r\n" \
    "Content-Encoding: deflate\r\n" \
    "Content-Length: #{body.bytesize}\r\n" \
    "\r\n" \
  )
  socket.print body
  socket.flush
end

puts "Starting server on port 3000"

server = ThreadedWebServer.new
server.start(number_of_workers: 8) do |socket|
  loop do
    request = Request.from_socket(socket)
    break unless request

    _regex, lambda = routes[request.method]&.find { |regex, _lambda| request.path[regex] }

    status, body = lambda&.call(request) || [404, STATIC_VIEWS.fetch("404.html.deflated")]


    respond(socket, status: status, body: body)
  end
end

shutdown = false

Signal.trap("TERM") { shutdown = true }
Signal.trap("QUIT") { shutdown = true }
Signal.trap("INT") { shutdown = true }

loop do
  if shutdown
    puts "Shutting down"
    server.shutdown
    exit
  end
  sleep 1
end
