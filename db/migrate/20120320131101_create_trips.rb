class CreateTrips < ActiveRecord::Migration
  def change
    create_table :trips do |t|
      t.integer :flight_id

      t.timestamps
    end
  end
end
