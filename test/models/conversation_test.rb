require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "persist and reloads a conversation with messages" do
    conversation = Conversation.create!(name: "test")
    conversation.messages.create!(role: "user", content: "My package is late.")
    conversation.messages.create!(role: "assistant", content: "What's the tracking?")
    conversation.reload

    assert_equal "test", conversation.name
    assert_equal ["user", "assistant"], conversation.messages.map(&:role)
    assert_equal ["My package is late.", "What's the tracking?"], conversation.messages.map(&:content)
  end

  test "load messages in correct order" do
    conversation = Conversation.create!(name: "test")
    message_a = Message.create!(role: "user", content: "third message", created_at: Time.utc(2026, 10, 19, 12, 0, 1), conversation: conversation)
    message_b = Message.create!(role: "user", content: "first message", created_at: Time.utc(2026, 10, 19, 12, 0, 0), conversation: conversation)
    message_c = Message.create!(role: "user", content: "second message", created_at: Time.utc(2026, 10, 19, 12, 0, 0), conversation: conversation)
    conversation.reload

    assert_equal [message_b.id, message_c.id, message_a.id], conversation.messages.map(&:id)
  end

  test "only loads messages belonging to the conversation" do
    conversation = Conversation.create!
    other_conversation = Conversation.create!
    message = conversation.messages.create!(role: "user", content: "Where is TEST-001?")
    other_message = other_conversation.messages.create!(role: "user", content: "Where is TEST-002?")

    assert_equal [message.id], conversation.reload.messages.map(&:id)
    assert_equal [other_message.id], other_conversation.reload.messages.map(&:id)
  end

  test "destroying a conversation removes its messages and preserves other conversations" do
    conversation = Conversation.create!
    user_message = conversation.messages.create!(role: "user", content: "My package is late.")
    assistant_message = conversation.messages.create!(role: "assistant", content: "What is the tracking number?")
    other_conversation = Conversation.create!
    other_message = other_conversation.messages.create!(role: "user", content: "Where is TEST-002?")

    conversation.destroy!

    assert_not Conversation.exists?(conversation.id)
    assert_not Message.exists?(user_message.id)
    assert_not Message.exists?(assistant_message.id)
    assert Conversation.exists?(other_conversation.id)
    assert_equal [other_message.id], other_conversation.reload.messages.map(&:id)
  end
end
