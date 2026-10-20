class ConversationService
  SYSTEM_PROMPT = "You are a shipping support assistant using fictional examples. Ask for missing information. Do not invent shipment details or shipping policies."

  def initialize(ai_client)
    @ai_client = ai_client
  end

  def create_conversation(name)
    Conversation.create!(name: name)
  end

  def process_message(conversation, content)
    conversation.messages.create!(role: "user", content: content)
    conversation.reload
    ai_messages = conversation.messages.where(role: %w[user assistant]).map { |message| { role: message.role, content: message.content } }
    ai_messages.prepend({ role: "system", content: SYSTEM_PROMPT })
    response = @ai_client.chat(ai_messages)
    conversation.messages.create!(role: "assistant", content: response)
  end
end
