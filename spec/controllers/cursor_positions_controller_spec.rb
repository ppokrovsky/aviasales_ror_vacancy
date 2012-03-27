require 'spec_helper'

describe CursorPositionsController do
  describe "POST" do
    describe "create" do
      it "should return http success" do
        @attrs = { :arr => [[254, 123], [123, 234]] }
        post("create", @attrs)
        response.should be_success
      end
    end
  end
end
