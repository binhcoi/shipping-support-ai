class Shipment < ApplicationRecord
  validates :tracking_number, presence: true, uniqueness: true
end
