class CursorPositionsController < ApplicationController
  # This action actually adds mouse coordinates to database
  def create
    # First of all we deserialize JSON from params
    arr = ActiveSupport::JSON.decode(params[:arr])

    # each element of params should contain an array of [x,y] or null (nil). We are interested only in arrays
    # and therefore all conditions below are executed only if coords is not nil
    arr.each do |coords|
      # we also would like to have a session id and page name for every record so we can build nice maps and
      # paths later.
      arg = {
          :session_id => request.session_options[:id],
          :page => request.fullpath.split("?")[0],
          :x => coords[0],
          :y => coords[1]
      } if coords

      # instantiating a model
      #@cursor_position = CursorPosition.new(arg) if coords
      # saving a record
      #@cursor_position.save! if coords

      # A stub to prevent actual saving. Uncomment @cursor_position lines below
    end
    render :text => "ok"
  end
end

