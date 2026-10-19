class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true, index: false
      t.string :role, null: false
      t.text :content, null: false

      t.timestamps

      t.index [:conversation_id, :created_at, :id]
    end
  end
end
