require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "return application health as JSON" do
    get "/health"
    assert_response :ok
    assert_equal "application/json", response.media_type
    expected_body = {
      "status" => "ok",
      "service" => "shipping_support_ai"
    }
    assert_equal expected_body, response.parsed_body
  end
end
