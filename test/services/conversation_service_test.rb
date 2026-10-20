require "test_helper"

class ConversationServiceTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :receive_messages, :call_count
    attr_accessor :response, :error

    def initialize
      @response = "default response"
      @call_count = 0
    end

    def chat(messages)
      @call_count += 1
      @receive_messages = messages
      raise error if error

      response
    end
  end

  test "successfully save user input, process correctly and return message" do
    client = FakeClient.new
    service = ConversationService.new(client)
    conversation = Conversation.create!(name: "test")
    test_content = "This is my test message"

    reply = service.process_message(conversation, test_content)

    assert_equal client.response, reply.content
    assert reply.persisted?
    assert_equal "assistant", reply.role
    assert_equal conversation.id, reply.conversation_id
    assert_equal 1, client.call_count
    assert_includes client.receive_messages, { role: "user", content: test_content }
    assert_includes conversation.messages.reload.map { |message| { role: message.role, content: message.content } },
                    { role: "assistant", content: client.response }
  end

  test "include history in order" do
    client = FakeClient.new
    service = ConversationService.new(client)
    conversation = Conversation.create!(name: "test")
    test_content_1 = "This is my test message"
    test_content_2 = "This is second"
    test_reply_1 = "welcome home"
    test_reply_2 = "i'm here"

    client.response = test_reply_1
    service.process_message(conversation, test_content_1)
    client.response = test_reply_2
    service.process_message(conversation, test_content_2)

    expected = [
      { role: "system", content: ConversationService::SYSTEM_PROMPT },
      { role: "user", content: test_content_1 },
      { role: "assistant", content: test_reply_1 },
      { role: "user", content: test_content_2 },
    ]

    assert_equal expected, client.receive_messages

    expected.shift
    expected << { role: "assistant", content: test_reply_2 }

    assert_equal expected,
                 conversation.messages.reload.map { |message| { role: message.role, content: message.content } }
  end

  test "creates a persisted conversation with the requested name" do
    service = ConversationService.new(FakeClient.new)
    conversation = nil

    assert_difference "Conversation.count", 1 do
      conversation = service.create_conversation("Fictional shipping question")
    end

    assert conversation.persisted?
    assert_equal "Fictional shipping question", conversation.reload.name
  end

  test "sends only the application system prompt even when a system message is persisted" do
    client = FakeClient.new
    service = ConversationService.new(client)
    conversation = Conversation.create!
    stored_prompt = conversation.messages.create!(role: "system", content: "An older set of instructions.")

    service.process_message(conversation, "Where is TEST-001?")

    assert_equal [
      { role: "system", content: ConversationService::SYSTEM_PROMPT },
      { role: "user", content: "Where is TEST-001?" },
    ], client.receive_messages
    assert_equal "An older set of instructions.", stored_prompt.reload.content
  end

  test "reads fresh ordered history when the association was already loaded" do
    client = FakeClient.new
    service = ConversationService.new(client)
    conversation = Conversation.create!
    conversation.messages.create!(
      role: "assistant", content: "What is the tracking number?",
      created_at: Time.utc(2026, 10, 19, 12, 1, 0),
    )
    conversation.messages.load

    other_instance = Conversation.find(conversation.id)
    other_instance.messages.create!(
      role: "user", content: "My package is late.",
      created_at: Time.utc(2026, 10, 19, 12, 0, 0),
    )

    service.process_message(conversation, "TEST-001")

    assert_equal [
      { role: "system", content: ConversationService::SYSTEM_PROMPT },
      { role: "user", content: "My package is late." },
      { role: "assistant", content: "What is the tracking number?" },
      { role: "user", content: "TEST-001" },
    ], client.receive_messages
  end

  test "does not send or change another conversation's history" do
    client = FakeClient.new
    service = ConversationService.new(client)
    conversation = Conversation.create!
    other_conversation = Conversation.create!
    other_message = other_conversation.messages.create!(role: "user", content: "Where is TEST-002?")

    reply = service.process_message(conversation, "Where is TEST-001?")

    assert_equal [
      { role: "system", content: ConversationService::SYSTEM_PROMPT },
      { role: "user", content: "Where is TEST-001?" },
    ], client.receive_messages
    assert_equal conversation.id, reply.conversation_id
    assert_equal [other_message.id], other_conversation.reload.messages.map(&:id)
    assert_equal "Where is TEST-002?", other_message.reload.content
  end

  { "nil" => nil, "empty" => "", "whitespace" => " \t\n" }.each do |description, content|
    test "rejects #{description} input without calling the client or changing history" do
      client = FakeClient.new
      service = ConversationService.new(client)
      conversation = Conversation.create!
      existing_message = conversation.messages.create!(role: "user", content: "Where is TEST-001?")

      assert_no_difference "Message.count" do
        error = assert_raises(ActiveRecord::RecordInvalid) do
          service.process_message(conversation, content)
        end
        assert error.record.errors.of_kind?(:content, :blank)
      end

      assert_equal 0, client.call_count
      assert_equal [existing_message.id], conversation.reload.messages.map(&:id)
      assert_equal "Where is TEST-001?", existing_message.reload.content
    end
  end

  test "propagates a client error and retains the user input without an assistant reply" do
    client = FakeClient.new
    client.error = OllamaClient::Error.new("Response timed out")
    service = ConversationService.new(client)
    conversation = Conversation.create!
    conversation.messages.create!(role: "user", content: "My package is late.")
    conversation.messages.create!(role: "assistant", content: "What is the tracking number?")

    assert_difference "conversation.messages.count", 1 do
      error = assert_raises(OllamaClient::Error) do
        service.process_message(conversation, "TEST-001")
      end
      assert_same client.error, error
    end

    assert_equal 1, client.call_count
    assert_equal [
      { role: "user", content: "My package is late." },
      { role: "assistant", content: "What is the tracking number?" },
      { role: "user", content: "TEST-001" },
    ], conversation.reload.messages.map { |message| { role: message.role, content: message.content } }
    assert_equal({ role: "user", content: "TEST-001" }, client.receive_messages.last)
  end

  test "rejects an empty assistant response while retaining the user input" do
    client = FakeClient.new
    client.response = ""
    service = ConversationService.new(client)
    conversation = Conversation.create!

    error = assert_raises(ActiveRecord::RecordInvalid) do
      service.process_message(conversation, "Where is TEST-001?")
    end

    assert_equal "assistant", error.record.role
    assert error.record.errors.of_kind?(:content, :blank)
    assert_equal 1, client.call_count
    assert_equal [
      { role: "user", content: "Where is TEST-001?" },
    ], conversation.reload.messages.map { |message| { role: message.role, content: message.content } }
  end
end
