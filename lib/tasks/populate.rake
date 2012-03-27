namespace :db do
  task :populate => :environment do
    require 'populator'

    Flight.destroy_all

    Flight.populate 50 do |flight|
      iatas = %w(SVO SVX SFO DME BKK KLX HKT HDY UMS)
      cities = %w(Sheremetyevo Koltsovo San-Francisco Domodedovo Bangkok Kuala-Lumpur Phuket Hatyai Samui)
      rnd_origin = rand(iatas.count)
      rnd_destination = rand(iatas.count)
      flight.origin_iata = iatas[rnd_origin]
      flight.origin_city = cities[rnd_origin]
      flight.departure = Time.now + (rand(3)).days + rand(10).hours
      flight.destination_iata = iatas[rnd_destination]
      flight.destination_city = cities[rnd_destination]
      flight.arrival = flight.departure + 1.hour + rand(10).hours + rand(59).minutes
      flight.price = rand(1000..9999)
    end

    # Remove invalid flights (origin = destination)
    Flight.where("origin_iata = destination_iata").delete_all
  end
end