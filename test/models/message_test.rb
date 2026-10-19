require "test_helper"

class MessageTest < ActiveSupport::TestCase
  %w[system user assistant].each do |role|
    test "persists a message with the #{role} role" do
      conversation = Conversation.create!
      message = conversation.messages.create!(role: role, content: "Fictional shipping conversation.")

      assert_equal role, message.reload.role
      assert_equal conversation.id, message.conversation_id
    end
  end

  { "unknown" => "test", "nil" => nil, "empty" => "", "whitespace" => " \t\n" }.each do |description, role|
    test "rejects a role that is #{description}" do
      message = Message.new(role: role, content: "Where is TEST-001?", conversation: Conversation.new)

      assert_not message.valid?
      assert message.errors.of_kind?(:role, :inclusion)
    end
  end

  { "nil" => nil, "empty" => "", "whitespace" => " \t\n" }.each do |description, content|
    test "rejects #{description} content" do
      message = Message.new(role: "user", content: content, conversation: Conversation.new)

      assert_not message.valid?
      assert message.errors.of_kind?(:content, :blank)
    end
  end

  test "requires a conversation" do
    message = Message.new(role: "user", content: "Where is TEST-001?")

    assert_not message.valid?
    assert message.errors.of_kind?(:conversation, :blank)
  end

  test "model and database reject a nonexistent conversation" do
    deleted_conversation = Conversation.create!
    deleted_conversation.destroy!
    message = Message.new(role: "user", content: "Where is TEST-001?", conversation_id: deleted_conversation.id)

    assert_not message.valid?
    assert message.errors.of_kind?(:conversation, :blank)

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Message.transaction(requires_new: true) do
        message.save!(validate: false)
      end
    end

    assert_not Message.exists?(conversation_id: deleted_conversation.id)
    conversation = Conversation.create!
    valid_message = conversation.messages.create!(role: "user", content: "Where is TEST-002?")
    assert_equal "Where is TEST-002?", valid_message.reload.content
  end

  %i[conversation_id role content].each do |attribute|
    test "database rejects a null #{attribute} when validations are bypassed" do
      conversation = Conversation.create!
      message = Message.new(role: "user", content: "Where is TEST-001?", conversation: conversation)
      message[attribute] = nil

      assert_raises(ActiveRecord::NotNullViolation) do
        Message.transaction(requires_new: true) do
          message.save!(validate: false)
        end
      end

      assert_empty conversation.reload.messages
      valid_message = conversation.messages.create!(role: "user", content: "Where is TEST-002?")
      assert_equal "Where is TEST-002?", valid_message.reload.content
    end
  end

  test "destroying a message preserves its conversation and sibling messages" do
    conversation = Conversation.create!
    message = conversation.messages.create!(role: "user", content: "My package is late.")
    sibling = conversation.messages.create!(role: "assistant", content: "What is the tracking number?")

    message.destroy!

    assert_not Message.exists?(message.id)
    assert Conversation.exists?(conversation.id)
    assert_equal [sibling.id], conversation.reload.messages.map(&:id)
  end
end
