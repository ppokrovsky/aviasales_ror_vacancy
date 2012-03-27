class CreateFlights < ActiveRecord::Migration
  def change
    create_table :flights do |t|
      t.string :origin_iata
      t.string :destination_iata
      t.datetime :departure
      t.datetime :arrival
      t.decimal :price, :precision => 7, :scale => 2

      t.timestamps
    end
  end
end
