class Message < ApplicationRecord
  belongs_to :conversation
  validates :role, inclusion: { in: %w[system user assistant] }
  validates :content, presence: true
end
