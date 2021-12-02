require 'socket'
server = TCPServer.new 3000

def respond(socket, body: "", status: 200)
  socket.print "HTTP/1.1 #{status}\r\n"
  socket.print "Content-Type: text/html\r\n"
  socket.print "\r\n"
  socket.print body
end

while socket = server.accept
  request = socket.gets

  respond(socket, body: File.read("app/views/index.html"))

  socket.close
end
