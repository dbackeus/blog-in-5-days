require 'socket'
require "zlib"
require "uri"

require_relative "lib/store_adapters/p_store_adapter"
require_relative "forked_web_server"
require_relative "threaded_web_server"
require_relative "app/models/post"

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
    %r{^/$} => lambda do |request|
      [200, STATIC_VIEWS.fetch("index.html.deflated")]
    end,
    %r{^/large/?$} => lambda do |request|
      [200, STATIC_VIEWS.fetch("large.html.deflated")]
    end,
    %r{^/posts/(?<id>\d+)/?$} => lambda do |request|
      post = Post.find_by_id(request.route_match[:id])
      body = <<~HTML
        <h1>#{post.title}</h1>
        #{post.body}
        <p>
          <a href="/posts">Back to posts</a>
        </p>
      HTML
      [200, Zlib::Deflate.deflate(body)]
    end,
    %r{^/posts/?$} => lambda do |request|
      posts = Post.all
      list_items = posts.map do |post|
        <<~HTML
          <li><a href="/posts/#{post.id}">#{post.title}</a></li>
        HTML
      end
      body = <<~HTML
        <h1>Posts</h1>
        <ul>
          #{list_items.join}
        </ul>
        <p>
          <a href="/posts/new">New Post</a>
        </p>
      HTML
      [200, Zlib::Deflate.deflate(body)]
    end,
    %r{^/posts/new$} => lambda do |request|
      [200, STATIC_VIEWS.fetch("posts_new.html.deflated")]
    end,
  },
  "POST" => {
    %r{^/posts/?$} => lambda do |request|
      params = URI.decode_www_form(request.body).to_h
      post = Post.create title: params["title"], body: params["body"]
      [301, "", { "Location" => "/posts/#{post.id}" }]
    end,
  }
}

def respond(socket, body: "", headers: nil, status: 200)
  headers_string = headers&.each_with_object("") do |(key, value), string|
    string << "#{key}: #{value}\r\n"
  end

  socket.print(
    "HTTP/1.1 #{status}\r\n" \
    "Content-Type: text/html\r\n" \
    "Content-Encoding: deflate\r\n" \
    "Content-Length: #{body.bytesize}\r\n" \
    "#{headers_string}" \
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

    _regex, lambda = routes[request.method]&.find do |regex, _lambda|
      next unless match = regex.match(request.path)

      request.route_match = match
    end

    status, body, headers = lambda&.call(request) || [404, STATIC_VIEWS.fetch("404.html.deflated")]

    respond(socket, status: status, body: body, headers: headers)
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
