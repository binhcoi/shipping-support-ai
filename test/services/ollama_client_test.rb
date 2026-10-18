require "test_helper"
require "webmock/minitest"

class OllamaClientTest < ActiveSupport::TestCase
  success_response_body = {
    "message": {
      "role": "assistant",
      "content": "Hello! How can I help you today?",
    },
  }

  base_url = "http://test_endpoint:11434"
  model = "test_model"
  messages = [{ role: "user", content: "Say hello in one sentence." }]
  request_body = {
    model: model,
    stream: false,
    think: false,
    messages: messages,
  }

  test "successful POST request" do
    stub_request(:post, "#{base_url}/api/chat")
      .with(body: request_body, headers: { "Content-Type" => "application/json" })
      .to_return(status: 200, body: success_response_body.to_json)

    response = OllamaClient.new(base_url, model).chat(messages)

    assert_equal "Hello! How can I help you today?", response
  end

  test "preserves message history and order" do
    history = [
      { role: "system", content: "Answer fictional shipping questions." },
      { role: "user", content: "My parcel is late." },
      { role: "assistant", content: "What is the tracking number?" },
      { role: "user", content: "TEST-001" },
    ]
    request_stub = stub_request(:post, "#{base_url}/api/chat")
      .with(
        body: request_body.merge(messages: history),
        headers: { "Content-Type" => "application/json" },
      )
      .to_return(status: 200, body: success_response_body.to_json)

    response = OllamaClient.new(base_url, model).chat(history)

    assert_equal "Hello! How can I help you today?", response
    assert_requested request_stub, times: 1
  end

  test "supports an HTTPS endpoint" do
    secure_url = "https://ollama.example:11434"
    stub_request(:post, "#{secure_url}/api/chat")
      .with(body: request_body, headers: { "Content-Type" => "application/json" })
      .to_return(status: 200, body: success_response_body.to_json)

    response = OllamaClient.new(secure_url, model).chat(messages)

    assert_equal "Hello! How can I help you today?", response
  end

  {
    404 => { error: "model not found" }.to_json,
    500 => "<html>Internal Server Error</html>",
  }.each do |status, response_body|
    test "raises a client error for HTTP #{status} before parsing the body" do
      stub_request(:post, "#{base_url}/api/chat")
        .to_return(status: status, body: response_body)

      error = assert_raises(OllamaClient::Error) do
        OllamaClient.new(base_url, model).chat(messages)
      end

      assert_includes error.message, status.to_s
    end
  end

  {
    Net::OpenTimeout => "Connection timed out",
    Net::ReadTimeout => "Response timed out",
    Errno::ECONNREFUSED => "Connection refused",
  }.each do |exception_class, expected_message|
    test "translates #{exception_class} into a client error" do
      stub_request(:post, "#{base_url}/api/chat")
        .to_raise(exception_class.new("simulated transport failure"))

      error = assert_raises(OllamaClient::Error) do
        OllamaClient.new(base_url, model).chat(messages)
      end

      assert_equal expected_message, error.message
      assert_kind_of exception_class, error.cause
    end
  end

  test "raises a client error for invalid JSON" do
    stub_request(:post, "#{base_url}/api/chat")
      .to_return(status: 200, body: "{not valid JSON")

    error = assert_raises(OllamaClient::Error) do
      OllamaClient.new(base_url, model).chat(messages)
    end

    assert_match(/JSON/, error.message)
    assert_kind_of JSON::ParserError, error.cause
  end

  {
    "null body" => nil,
    "array body" => [],
    "missing message" => {},
    "null message" => { message: nil },
    "array message" => { message: [] },
    "string message" => { message: "unexpected" },
    "missing content" => { message: {} },
    "null content" => { message: { content: nil } },
    "numeric content" => { message: { content: 42 } },
    "boolean content" => { message: { content: false } },
    "array content" => { message: { content: [] } },
    "object content" => { message: { content: {} } },
  }.each do |description, response_body|
    test "rejects a response with #{description}" do
      stub_request(:post, "#{base_url}/api/chat")
        .to_return(status: 200, body: response_body.to_json)

      error = assert_raises(OllamaClient::Error) do
        OllamaClient.new(base_url, model).chat(messages)
      end

      assert_equal "Unexpected response structure", error.message
    end
  end
end
