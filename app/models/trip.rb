# Technically this doesn't have to be ActiveRecord::Base child, because at this stage it doesn't do any validations
# and saves etc, but for the convenience and to avoid overriding ActiveRecord methods we still declaring it as such
# and creating a corresponding dummy table in database.
# Besides in future we may want to save search results and do validations and stuff
class Trip  < ActiveRecord::Base
  # This class uses RubyTree gem for n-ary trees, therefore it needs to be added to Gemfile
  require 'tree'

  attr_accessor :origin_iata, :destination_iata, :max_stops, :min_departure, :max_price, :max_trip_time
  attr_accessor :result

  # This method uses n-ary tree to build all possible routes from origin to destination
  # It implements validations, like destination validation, route loops and time loops
  # Constraints, like times, transits and prices can be applied, but defaults are nil
  def self.build_trip(origin_iata, destination_iata, max_stops = nil, min_departure = nil, max_price = nil, max_trip_time = nil)

    # A bit of input parameters sanitization
    if max_stops && max_stops == ""
      max_stops = nil
    else
      max_stops = max_stops.to_i
    end

    if min_departure && min_departure == ""
      min_departure = nil
    else
      min_departure = min_departure.to_s
    end

    if max_price && max_price == ""
      max_price = nil
    else
      max_price = max_price.to_i
    end

    if max_trip_time && max_trip_time == ""
      max_trip_time = nil
    else
      max_trip_time = max_trip_time.to_i
    end

    # Trees array is where we will store our route trees
    trees = []

    # First we apply min_departure constraint since this potentially will reduce number of possible routes and
    # improve performance. If min_departure is set, we call 'where' with sql injection-safe parameters
    # otherwise we just call good old 'find_all_by'
    if min_departure
      origins = Flight.where("origin_iata = ? and departure >= ?", origin_iata, min_departure)
    else
      origins = Flight.where(:origin_iata => origin_iata)
    end

    # Create trees roots (origin flights)
    origins.each_with_index do |origin, index|
      trees[index] = Tree::TreeNode.new(origin.id, origin.to_json)
    end

    # Build trees
    trees.each do |tree|
      tree.each_leaf do |leaf|
        content = ActiveSupport::JSON.decode(leaf.content)
        flights = Flight.where(:origin_iata => content["destination_iata"])
        flights.each do |flight|
          leaf.add(Tree::TreeNode.new(flight.id, flight.to_json)) unless
              route_loop_exists?(tree, origin_iata, flight.destination_iata) or
              destination_found?(tree, flight.origin_iata, destination_iata)
              # We can put time loop check in here, but it will generate apocalyptic amount of db requests,
              # because it will check through all routes, even invalid by default (!destination)
              # Therefore this check should be done after initial validation of tree
        end
      end
    end

    # Traverse trees and remove invalid routes (!destination)
    trees.each do |tree|
      validate_route(tree, destination_iata)
    end

    # Produce readable arrays.
    @routes = []
    trees.each do |tree|
      #if tree children count = 0, it is a direct flight
      if tree.children.count == 0
        @routes << tree
      else
        tree.each_leaf{|leaf| @routes << build_branch(leaf) }
      end
    end

    # Probably it is better to validate transits here, because later we will be validating times and this is kind of
    # resource consuming task, so the less elements will be in @trips by then, the better
    # We basically don't care that much about collection integrity and index shifts here and in next validation
    # because we addressing @routes array with route and not index
    @routes.delete_if{ |route| transit_limit_reached?(route, max_stops) } if max_stops

    # Validating times is very resource consuming task because it goes to database for every trip in array
    # But since we are not looking for perfect algorithm, this should do as well. Besides we apply plenty of
    # constraints before this task, so our @trips array hopefully should not contain that many elements
    # Potentially, during initial tree construction, we can put something like a JSON string in tree node content,
    # which will contain all the fields from corresponding database record, so time_loop_exists? method won't have to
    # crawl database every time
    @routes.delete_if{ |route| time_loop_exists?(route) }

    # Now it's a good time to calculate total price for every trip, because later we will apply total price constraint
    @total_prices = []
    @routes.each_with_index do |route, index|
      @total_prices[index] = calculate_total(route)
    end

    # Validate prices
    # This section looks very strange, but actually this is according to Ruby Best-Practice
    # "Do not modify a collection while traversing it" and we're traversing array with indexes which may shift
    # if we delete elements on-the-fly. That's why we're producing copies of arrays and then re-assign initial arrays
    if max_price
      valid_routes = []
      valid_totals = []
      @routes.each_index do |index|
        valid_routes << @routes[index] if @total_prices[index] <= max_price
        valid_totals << @total_prices[index] if @total_prices[index] <= max_price
      end
      @routes = valid_routes
      @total_prices = valid_totals
    end

    # Calculate times in flight
    @flight_times = []
    @routes.each_with_index do |route, index|
      @flight_times[index] = calculate_flight_times(route)
    end

    # Calculate times in transit
    @transits = []
    @routes.each_with_index do |route, index|
      @transits[index] = calculate_transits(route)
    end

    # Calculate total times
    @total_times = []
    @routes.each_index do |route_index|
      total_time = 0
      @flight_times[route_index].each do |flight_time|
        total_time = total_time + flight_time[0] * 1440 + flight_time[1] * 60 + flight_time[2]
      end
      @transits[route_index].each do |transit_time|
        total_time = total_time + transit_time[0] * 1440 + transit_time[1] * 60 + transit_time[2]
      end
      @total_times[route_index] = total_time
    end
    @total_times.each_with_index do |total_time, index|
      @total_times[index] = minutes_to_arr(total_time)
    end

    # Check max_trip_time constraint
    if max_trip_time
      valid_routes = []
      valid_totals = []
      valid_times = []
      @routes.each_index do |index|
        valid_routes << @routes[index] if to_hours(@total_times[index]) <= max_trip_time
        valid_totals << @total_prices[index] if to_hours(@total_times[index]) <= max_trip_time
        valid_times << @total_times[index] if to_hours(@total_times[index]) <= max_trip_time
      end
      @routes = valid_routes
      @total_prices = valid_totals
      @total_times = valid_times
    end

    @total_times_in_hours = []
    @routes.each_index do |index|
      @total_times_in_hours[index] = to_hours(@total_times[index])
    end

    # By this point we have valid routes, totals and transits so we put them in Hash and return it
    @result = {
        routes: @routes,
        transits: @transits,
        flight_times: @flight_times,
        total_prices: @total_prices,
        total_times: @total_times,
        total_times_in_hours: @total_times_in_hours}
  end

  # In this section we define various helper functions. They all declared private since they are supposed to be
  # called only from within this class
  private

  # This helper detects if route loop exists. Route loop is defined as when one of the destinations in tree is
  # equal to departures and this destination is not our final destination
  def self.route_loop_exists?(tree, origin_iata, iata)
    tree.each do |node|
      content = ActiveSupport::JSON.decode(node.content)
      if iata == content["origin_iata"] or iata == origin_iata
        return true unless node.is_leaf?
      end
    end
    false
  end

  # This helper detects if destination is found. If it is true, then build_trip will stop appending leafs to
  # branch
  def self.destination_found?(tree, iata, destination_iata)
    tree.each do
      if iata == destination_iata
        true
      end
    end
    false
  end

  # This helper detects if route is valid, so that tree leaf is equal to destination_iata. All invalid routes
  # are removed from tree. It is a bit overcomplicated, because remove_from_parent! method from Rubytree gem does not
  # declare parent a leaf when last leaf is removed.
  def self.validate_route(tree, destination_iata)
    # count all leafs
    i = 0
    tree.each_leaf{ i+= 1}

    # count valid routes
    j = 0
    tree.each_leaf do |leaf|
      content = ActiveSupport::JSON.decode(leaf.content)
      if content["destination_iata"] == destination_iata
        j += 1
      end
    end

    # difference between all leafs (routes) and valid leafs (=destination_iata) is invalid route.
    # We run while loop against this value
    invalid_routes = i-j

    # traverse tree and remove invalid_routes
    while invalid_routes > 0
      tree.each_leaf do |leaf|
        content = ActiveSupport::JSON.decode(leaf.content)
        leaf.remove_from_parent! unless content["destination_iata"] == destination_iata
      end
      invalid_routes -= 1
    end
    tree
  end

  # This helper detects if time loop exists. Time loop is defined as situation, when next flight departs before
  # previous flight in route arrives
  def self.time_loop_exists?(route)
    # check if destination.departure < parent.arrival. If true, it means that flight left before connection arrived
    # and therefore this route is invalid. We also do reverse_each traversal here to avoid random index shifts
    if route.kind_of?(Array)
      index = route.length - 1
      route.reverse_each do
        while index > 0 do
          departure = ActiveSupport::JSON.decode(route[index].content)["departure"]
          arrival = ActiveSupport::JSON.decode(route[index-1].content)["arrival"]
          if departure < arrival
            return true
          end
          index -= 1
        end
      end
    else
      # if trip is not Array this is a direct trip which in terms of time is valid by default
      return false
    end
    false
  end

  # This helper detects if route contains more transit stops, than defined by user
  def self.transit_limit_reached?(route, max_stops)
    return true if route.count > max_stops + 1
    false
  end

  # This helper calculates total price for the trip
  def self.calculate_total(route)
    total = 0
    route.each do |flight|
      price = ActiveSupport::JSON.decode(flight.content)["price"]
      total = total + price.to_f
    end
    total
  end

  # This helper calculates times in transit for non-direct flights
  def self.calculate_transits(route)
    if route.kind_of?(Array)
      i = 0
      # For every route number of transit stop is number of stops -1
      index = route.length - 1
      transits = []
      while i < index do
        arrival = ActiveSupport::JSON.decode(route[i].content)["arrival"].to_time
        departure = ActiveSupport::JSON.decode(route[i+1].content)["departure"].to_time
        mm = ((departure - arrival) / 1.minute).round
        transits << minutes_to_arr(mm)
        i += 1
      end
      transits
    else
      [0]
    end
  end

  # This helper calculates times in flight.
  def self.calculate_flight_times(route)
    flight_times = []
    if route.kind_of?(Array)
      route.each do |flight|
        departure = ActiveSupport::JSON.decode(flight.content)["departure"].to_time
        arrival = ActiveSupport::JSON.decode(flight.content)["arrival"].to_time
        mm = ((arrival - departure) / 1.minute).round
        flight_times << minutes_to_arr(mm)
      end
    else
      # Direct flight
      departure = ActiveSupport::JSON.decode(route.content)["departure"].to_time
      arrival = ActiveSupport::JSON.decode(route.content)["arrival"].to_time
      mm = ((arrival - departure) / 1.minute).round
      flight_times << minutes_to_arr(mm)
    end
    flight_times
  end

  # This helper transforms time in minutes to array [dd, hh, mm]
  def self.minutes_to_arr(time_in_minutes)
    hh, mm = time_in_minutes.divmod(60)
    dd, hh = hh.divmod(24)
    [dd, hh, mm]
  end

  def self.to_hours(time_array)
    time_array[0] * 24 + time_array[1] + 1
  end

  # This helper transforms output of RubyTree parentage method to direct array and appends destination_iata leaf
  def self.build_branch(leaf)
    return nil if leaf.is_root?
    branch_array = leaf.parentage
    branch_array = branch_array.reverse
    branch_array << leaf

    branch_array
  end
end
