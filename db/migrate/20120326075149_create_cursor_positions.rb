class CreateCursorPositions < ActiveRecord::Migration
  def change
    create_table :cursor_positions do |t|
      t.string :session_id
      t.string :page
      t.integer :x
      t.integer :y

      t.timestamps
    end
  end
end
