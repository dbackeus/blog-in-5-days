class Post
  POSTS_BY_ID = {}

  def self.create(title:, body:)
    post = Post.new(id: POSTS_BY_ID.length + 1, title: title, body: body)
    POSTS_BY_ID[post.id] = post
  end

  def self.find_by_id(id)
    POSTS_BY_ID[id.to_i]
  end

  attr_reader :id, :title, :body

  def initialize(id:, title:, body:)
    @id = id
    @title = title
    @body = body
  end
end
