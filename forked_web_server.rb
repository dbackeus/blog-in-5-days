class ForkedWebServer
  def start(number_of_workers: 1, &block)
    server = TCPServer.new 3000

    @worker_pids = number_of_workers.times.map do |i|
      puts "Forking worker #{i + 1} / #{number_of_workers}"
      fork do
        loop do
          socket = server.accept
          socket.sync = false
          block.call(socket)
        rescue Errno::ECONNRESET, Interrupt
        ensure
          socket&.close
        end
      end
    end
  end

  def shutdown
    @worker_pids.each { |pid| Process.kill("TERM", pid) }
    @worker_pids.each { |pid| Process.wait(pid) }
  end
end
