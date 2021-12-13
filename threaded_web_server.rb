class ThreadedWebServer
  def start(number_of_workers: 1, &block)
    server = TCPServer.new 3000

    @threads = number_of_workers.times.map do |i|
      puts "Starting thread #{i + 1} / #{number_of_workers}"
      Thread.new do
        loop do
          socket = server.accept
          socket.sync = false
          block.call(socket)
        rescue Errno::ECONNRESET
        ensure
          socket&.close
        end
      end
    end
  end

  def shutdown
    @threads.each(&:kill).each(&:join)
  end
end
