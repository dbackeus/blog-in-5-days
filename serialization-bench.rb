require "faker"
require "yaml"
require "google/protobuf"
require "oj"
require "simdjson"

post_hashes_by_id = 10000.times.each_with_object({}) do |i, hash|
  id = i
  title = Faker::Book.title
  body = Faker::Lorem.paragraphs(number: 10).map { |p| "<p>#{p}</p>" }.join("\n")
  time = Time.now

  hash[id] = { id: id, title: title, body: body, created_at: time, updated_at: time }
end

class Post
  attr_reader :id, :title, :body, :created_at, :updated_at

  def initialize(id:, title:, body:, created_at: nil, updated_at: nil)
    @id = id
    @title = title
    @body = body
    @created_at = created_at
    @updated_at = updated_at
  end
end

posts_by_id = post_hashes_by_id.each_with_object({}) do |(id, post_hash), hash|
  hash[id] = Post.new(**post_hash)
end

require "benchmark"

def hash_to_string(hash)
  string = ""
  hash.each_value do |hash|
    string << hash[:id]
    string << hash[:title]
    string << hash[:body]
    string << hash[:created_at].to_f.to_s
    string << hash[:updated_at].to_f.to_s
  end
end

def post_to_string(hash)
  string = ""
  hash.each_value do |post|
    string << post.id
    string << post.title
    string << post.body
    string << post.created_at.to_f.to_s
    string << post.updated_at.to_f.to_s
  end
end

def benchmark_dumping(description, hash)
  puts description
  Benchmark.bm(10) do |bm|
    bm.report("marshal:") do
      Marshal.dump(hash)
    end
    # bm.report("to_json:") do
    #   hash.to_json
    # end
    # bm.report("to_yaml:") do
    #   hash.to_yaml
    # end
    bm.report("Oj.dump:") do
      Oj.dump(hash)
    end

    if hash.first[1].is_a?(Hash)
      bm.report("string_dump:") do
        hash_to_string(hash)
      end
    else
      bm.report("string_dump:") do
        post_to_string(hash)
      end
    end
  end
end

benchmark_dumping("== hashes ==", post_hashes_by_id)
benchmark_dumping("== posts ==", posts_by_id)
