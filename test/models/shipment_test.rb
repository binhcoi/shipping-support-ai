require "test_helper"

class ShipmentTest < ActiveSupport::TestCase
  test "is valid with a tracking number" do
    shipment = Shipment.new(tracking_number: "TEST-001")

    assert shipment.valid?, shipment.errors.full_messages.join(", ")
  end

  test "rejects a blank tracking number" do
    shipment = Shipment.new(tracking_number: "")

    assert_not shipment.valid?
    assert shipment.errors.of_kind?(:tracking_number, :blank)
  end

  test "rejects a duplicate tracking number" do
    Shipment.create!(tracking_number: "TEST-001")
    shipment = Shipment.new(tracking_number: "TEST-001")

    assert_not shipment.valid?
    assert shipment.errors.of_kind?(:tracking_number, :taken)
  end

  test "db index rejects a duplicate tracking number" do
    Shipment.new(tracking_number: "TEST-001").save!(validate: false)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Shipment.transaction(requires_new: true) do
        Shipment.new(tracking_number: "TEST-001").save!(validate: false)
      end
    end

    assert_equal 1, Shipment.where(tracking_number: "TEST-001").count
  end
end
