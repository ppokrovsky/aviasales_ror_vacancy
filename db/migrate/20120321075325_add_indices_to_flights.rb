class AddIndicesToFlights < ActiveRecord::Migration

  def self.up
    add_index :flights, :origin_iata
    add_index :flights, :destination_iata
  end

  def self.down
    remove_index :flights, :origin_iata
    remove_index :flights, :destination_iata
  end

end
