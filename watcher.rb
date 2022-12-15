def find_last_file_modified_at
  # 1638742291 ./watcher.rb
  # 1638730266 ./blog.rb
  # 1638730200 ...
  sorted_files = `find -X . -type f -not -path "./.git*" -not -name "*.DS_Store" | xargs stat -f "%m %N" | sort -rn`
  sorted_files[/^\d+/]
end

server_pid = nil
last_file_modified_at = nil

loop do
  new_last_file_modified_at = find_last_file_modified_at
  if(last_file_modified_at != new_last_file_modified_at)
    puts "[watcher.rb] Detected file modified, restarting server"
    last_file_modified_at = new_last_file_modified_at
    if server_pid
      Process.kill("TERM", server_pid)
      Process.wait(server_pid)
    end

    server_pid = Process.spawn("ruby blog.rb")
  end
  sleep 1
end
