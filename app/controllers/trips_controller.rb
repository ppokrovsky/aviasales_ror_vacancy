class TripsController < ApplicationController
  def new
    @trip = Trip.new
    @flights_origin = Flight.select(:origin_iata).uniq.order(:origin_iata)
    @flights_destination = Flight.select(:destination_iata).uniq.order(:destination_iata)
  end

  def create
    if params[:origin_iata].blank? || params[:destination_iata].blank?
      redirect_to new_trip_path, :notice => "Both Origin and Destination IATAs must present"
    else
      @result = Trip.build_trip(
          params[:origin_iata],
          params[:destination_iata],
          params[:max_stops],
          params[:min_departure],
          params[:max_price],
          params[:max_trip_time])
    end
  end
end