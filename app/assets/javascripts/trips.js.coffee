# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/
jQuery ->
  $('select').change ->
    elem = $(this)
    val = elem.val()
    $.ajax(
      url: "/flights/" + val + "/city",
      type: "get",
      dataType: "json",
      contentType: "application/json",
      processData: "false",
      success: (json) ->
        $.each(json, (key, city_name)-> elem.next("span").html(city_name))
    )
