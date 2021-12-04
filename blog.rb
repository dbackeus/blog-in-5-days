require 'socket'
require "zlib"

server = TCPServer.new 3000

STATIC_VIEWS = Dir.glob("app/views/*").each_with_object({}) do |path, hash|
  view = File.read(path)
  hash[File.basename(path)] = view
  hash["#{File.basename(path)}.deflated"] = Zlib::Deflate.deflate(view)
end

routes = {
  "GET" => {
    %r{/$} => lambda do
      [200, STATIC_VIEWS.fetch("index.html.deflated")]
    end,
    %r{/large/?$} => lambda do
      [200, STATIC_VIEWS.fetch("large.html.deflated")]
    end,
    %r{/posts/?$} => lambda do
      [200, STATIC_VIEWS.fetch("posts.html.deflated")]
    end,
  }
}

def extract_request(socket)
  first_line = socket.gets
  return unless first_line # client is done requesting over the keep alive connection

  method, path, http_version = first_line.split(" ")
  rest = ""
  while (line = socket.gets) && (line != "\r\n")
    rest << line
  end
  [method, path, rest]
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

loop do
  socket = server.accept
  socket.sync = false
  fork do
    loop do
      request = extract_request(socket)
      break unless request

      method, path, rest = request

      _regex, lambda = routes[method]&.find { |regex, _lambda| path[regex] }

      status, body = lambda ? lambda.call : [404, STATIC_VIEWS.fetch("404.html.deflated")]

      respond(socket, status: status, body: body)
    end
  rescue Errno::ECONNRESET
  ensure
    socket.close
  end
end
