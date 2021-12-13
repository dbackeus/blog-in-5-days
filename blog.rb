require 'socket'
require "zlib"

require_relative "forked_web_server"
require_relative "threaded_web_server"

STATIC_VIEWS = Dir.glob("app/views/*").each_with_object({}) do |path, hash|
  view = File.read(path)
  hash[File.basename(path)] = view
  hash["#{File.basename(path)}.deflated"] = Zlib::Deflate.deflate(view)
end

routes = {
  "GET" => {
    %r{/$} => lambda do |body|
      [200, STATIC_VIEWS.fetch("index.html.deflated")]
    end,
    %r{/large/?$} => lambda do |body|
      [200, STATIC_VIEWS.fetch("large.html.deflated")]
    end,
    %r{/posts/?$} => lambda do |body|
      [200, STATIC_VIEWS.fetch("posts.html.deflated")]
    end,
    %r{/posts/new$} => lambda do |body|
      [200, STATIC_VIEWS.fetch("posts_new.html.deflated")]
    end,
  },
  "POST" => {
    %r{/posts/?$} => lambda do |body|
      puts body
      [404, STATIC_VIEWS.fetch("404.html.deflated")]
    end,
  }
}

CARRIAGE_RETURN = "\r\n"

def extract_request(socket)
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
  [method, path, headers, body]
end

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
    request = extract_request(socket)
    break unless request

    method, path, headers, body = request

    _regex, lambda = routes[method]&.find { |regex, _lambda| path[regex] }

    status, body = lambda ? lambda.call(body) : [404, STATIC_VIEWS.fetch("404.html.deflated")]

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
