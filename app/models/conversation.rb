class Conversation < ApplicationRecord
  has_many :messages, -> { order(created_at: :asc, id: :asc) }, dependent: :destroy
end
