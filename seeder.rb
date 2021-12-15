require "faker"
require "net/http"

Net::HTTP.start("localhost", 3000) do |http|
  10000.times do
    request = Net::HTTP::Post.new("/posts")
    request.set_form_data(
      "title" => Faker::Book.title,
      "body" => Faker::Lorem.paragraphs(number: 10).map { |p| "<p>#{p}</p>" }.join("\n"),
    )
    http.request(request)
  end
end
