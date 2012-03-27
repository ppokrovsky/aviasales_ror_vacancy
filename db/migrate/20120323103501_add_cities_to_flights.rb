class AddCitiesToFlights < ActiveRecord::Migration
  def change
    add_column :flights, :origin_city, :string
    add_column :flights, :destination_city, :string
 end
end
