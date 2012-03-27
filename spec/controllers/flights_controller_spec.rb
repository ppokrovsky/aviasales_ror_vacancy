require 'spec_helper'

describe FlightsController do

  describe "GET 'show_city'" do
    it "returns http success" do
      get 'show_city'
      response.should be_success
    end
  end

end
