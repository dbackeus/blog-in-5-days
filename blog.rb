require 'socket'
server = TCPServer.new 3000

def respond(socket, body: "", status: 200)
  socket.print "HTTP/1.1 #{status}\r\n"
  socket.print "Content-Type: text/html\r\n"
  socket.print "Content-Length: #{body.bytesize}\r\n"
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

loop do
  socket = server.accept
  fork do
    loop do
      request = extract_request(socket)
      break unless request

      method, path, rest = request

      _regex, lambda = routes[method]&.find { |regex, _lambda| path[regex] }

      status, body = lambda ? lambda.call : [404, STATIC_VIEWS.fetch("404.html")]

      respond(socket, status: status, body: body)
    end
    socket.close
  end
end
