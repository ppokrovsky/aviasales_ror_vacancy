require 'spec_helper'

describe TripsController do
  render_views

  describe "new" do
    describe "get" do
      it "should return http success" do
        get 'new'
        response.should be_success
      end

      it "should render a search form" do
        get 'new'
        response.should have_selector("form", :action => "/trips")
      end
    end


  end

  describe "create" do
    describe "post" do
      it "should render results if destination_iata and origin_iata are present" do
        @attributes = { :origin_iata => "SVO", :destination_iata => "HDY", :max_stops => "1", :min_departure => "2012-03-21", :max_price => "10000"}
        post("create", @attributes)
        response.should be_success
        response.should have_selector("ul")
        response.should have_selector("li")
      end

      it "should redirect to new_trip_path if destination_iata or origin_iata not present" do
        @attributes = { :max_stops => "1", :min_departure => "2012-03-21", :max_price => "10000"}
        post("create", @attributes)
        response.should redirect_to new_trip_path
      end
    end
  end
end
