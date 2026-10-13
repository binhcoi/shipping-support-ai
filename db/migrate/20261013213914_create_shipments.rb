class CreateShipments < ActiveRecord::Migration[7.2]
  def change
    create_table :shipments do |t|
      t.string :tracking_number, null: false
      t.timestamps
      t.index :tracking_number, unique: true
    end
  end
end
