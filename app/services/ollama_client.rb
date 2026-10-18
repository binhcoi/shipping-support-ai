require "net/http"
require "json"

class OllamaClient
  class Error < StandardError; end

  def initialize(base_url, model, open_timeout = 3, read_timeout = 60)
    @base_url = base_url
    @model = model
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def chat(messages)
    uri = URI("#{@base_url}/api/chat")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = {
      model: @model,
      stream: false,
      think: false,
      messages: messages,
    }.to_json

    response = http.request(request)

    raise Error.new("request failed with code #{response.code}") unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)

    valid_response =
      body.is_a?(Hash) &&
      body["message"].is_a?(Hash) &&
      body["message"]["content"].is_a?(String)
    raise Error.new("Unexpected response structure") unless valid_response

    body["message"]["content"]
  rescue Net::OpenTimeout
    raise Error.new("Connection timed out")
  rescue Net::ReadTimeout
    raise Error.new("Response timed out")
  rescue Errno::ECONNREFUSED
    raise Error.new("Connection refused")
  rescue JSON::ParserError
    raise Error.new("Error parsing JSON")
  end
end
