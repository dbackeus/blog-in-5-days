require "pstore"

class Post
  def self.store
    @store ||= PStoreAdapter.new
  end

  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  POSTS_BY_ID = store.read || {}
  finnish = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  puts "loaded database in #{finnish}"

  Thread.new do
    loop do
      sleep 10
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      store.write(POSTS_BY_ID)
      finnish = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      puts "synced database in #{finnish}"
    end
  end

  def self.create(title:, body:)
    time = Time.now
    post = Post.new(
      id: POSTS_BY_ID.length + 1,
      title: title,
      body: body,
      created_at: time,
      updated_at: time,
    )
    POSTS_BY_ID[post.id] = post
  end

  def self.all
    POSTS_BY_ID.values
  end

  def self.find_by_id(id)
    POSTS_BY_ID[id.to_i]
  end

  attr_reader :id, :title, :body, :created_at, :updated_at

  def initialize(id:, title:, body:, created_at: nil, updated_at: nil)
    @id = id
    @title = title
    @body = body
    @created_at = created_at
    @updated_at = updated_at
  end
end
