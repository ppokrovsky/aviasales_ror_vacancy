# Set up temporary and result arrays. In tmp_pos we will store immediate coordinates. In cursor_position coordinates
# in the end of every 30 ms
tmp_pos = []
cursor_position = []

# Populating tmp_pos array
$(document).mousemove (e) ->
  tmp_pos.push([e.pageX, e.pageY])

# We run this routine every 30 ms. It takes last value of tmp_pos, pushes it to cursor_position and resets tmp_pos
setInterval ->
  cursor_position.push(tmp_pos[tmp_pos.length - 1])
  #$("#cursor_position").html("X:" + tmp_pos[tmp_pos.length][0] + " Y:" + tmp_pos[tmp_pos.length][1])
  tmp_pos.length = 0
, 30

# This function sends contents of cursor_position to server as ajax request. Before that we serialize cursor_position to
# JSON. If we have success response from server, we reset cursor_position. Otherwise if we couldn't save an ajax for
# some reason, we would like to preserve cursor_position values and try to send them in the next iteration
setInterval ->
  $.ajax(
    url: "/cursor_positions",
    type: "post",
    data: "arr=" + JSON.stringify(cursor_position),
    success: ->
      cursor_position.length = 0
    )
, 10000







