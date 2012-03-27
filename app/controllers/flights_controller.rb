class FlightsController < ApplicationController

  respond_to :json

  def show_city
    @city = Flight.where(:origin_iata => params[:iata]).uniq.pluck(:origin_city)
    respond_with(@city)
  end
end
