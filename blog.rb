require 'socket'
server = TCPServer.new 3000

def respond(socket, body: "", status: 200)
  socket.print "HTTP/1.1 #{status}\r\n"
  socket.print "Content-Type: text/html\r\n"
  socket.print "\r\n"
  socket.print body
end

STATIC_VIEWS = Dir.glob("app/views/*").each_with_object({}) do |path, hash|
  hash[File.basename(path)] = File.read(path)
end

routes = {
  "GET" => {
    %r{/$} => lambda do
      [200, STATIC_VIEWS.fetch("index.html")]
    end,
    %r{/posts/?$} => lambda do
      [200, STATIC_VIEWS.fetch("posts.html")]
    end,
  }
}

while socket = server.accept
  request = socket.gets

  method, path, http_version = request.split(" ")

  _regex, lambda = routes[method].find { |regex, _lambda| path[regex] }

  status, body = lambda ? lambda.call : [404, STATIC_VIEWS.fetch("404.html")]

  respond(socket, status: status, body: body)

  socket.close
end
