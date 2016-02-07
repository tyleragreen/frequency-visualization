#!/usr/bin/ruby
#----------------------------------------------------
#
# Author: Tyler Green (greent@tyleragreen.com)
#
#----------------------------------------------------
require 'net/http'
require 'json'
require 'openssl'
require 'date'

$stdout.sync = true

#----------------------------------------------------
# Constants
#----------------------------------------------------
OUTPUT_DIR             = "output"
START_TIME             = Time.new(2016,01,22,7,30,00)
END_TIME               = Time.new(2016,01,22,8,00,00)
WINDOW_LENGTH_IN_HOURS = (END_TIME - START_TIME) / 3600
DEFAULT_DATE           = START_TIME.strftime("%Y-%m-%d")
DEFAULT_TIME_FRAME     = "#{START_TIME.strftime("%H:%M:%S")},#{END_TIME.strftime("%H:%M:%S")}"
SUBWAY_ONESTOP_ID      = "f-dr5r-nyctsubway"
NYC_BOX                = [ -80.0, 35.0,
                           -73.0, 41.0 ]

#----------------------------------------------------
# Class to handle reads of the Transitland API
#----------------------------------------------------
class TransitlandAPIReader

  HOSTNAME           = "https://transit.land/api/v1/"
  PER_PAGE           = 1000

  #----------------------------------------------------
  # Set up instance variables of a TransitlandAPIReader object
  def initialize(bounding_box, date, time_frame)
    @bounding_box = bounding_box
    @date         = date
    @time_frame   = time_frame
  end

  #----------------------------------------------------
  # Fetch JSON data from a given URL, save attributes with
  # a given field name, and handle pagination (Transitland-specific)
  def get_json_data(url, field)
    results = {}
    data    = []

    begin
      puts "URL #{url}"
      uri              = URI.parse(url)
      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request  = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      results  = JSON.parse(response.body)
      data    += results[field]
      puts data.length

    end while url = results["meta"]["next"]
    
    return data
  end

  #----------------------------------------------------
  # Fetch the schedule_stop_pair list for the given time and bounding box
  def get_schedule_stop_pairs
    pairs_url  = "#{HOSTNAME}schedule_stop_pairs?"
    pairs_url += "per_page=#{PER_PAGE}&bbox=#{@bounding_box.join(',')}&date=#{@date}&origin_departure_between=#{@time_frame}"
    return get_json_data(pairs_url, "schedule_stop_pairs")
  end

  #----------------------------------------------------
  # Fetch the stops in the given bounding box
  def get_stops
    stops_url  = "#{HOSTNAME}stops?per_page=#{PER_PAGE}&bbox=#{@bounding_box.join(',')}"
    stop_array = get_json_data(stops_url, "stops")

    stop_hash = {}
    stop_array.each do |stop|
      stop_hash[stop["onestop_id"]] = stop
    end

    return stop_hash
  end


  #----------------------------------------------------
  # Lookup a single stop by its onestop_id
  def get_stop(onestop_id)

    # Lookup the stops the first time this is called
    # and save them for subsequent calls
    unless @stops
      @stops = get_stops
    end

    return @stops[onestop_id]
  end

end

#----------------------------------------------------
# Main script flow
#----------------------------------------------------
reader           = TransitlandAPIReader.new(NYC_BOX, DEFAULT_DATE, DEFAULT_TIME_FRAME)
edges            = {}
edges.default    = 0
features         = { :bus => [], :subway => [], :both => [] }

# Iterate through the stop pairs (transit route between two stops that departed in the specified time frame)
# and count the number of times each edge occurs to begin to tabulate frequency
reader.get_schedule_stop_pairs.each do |edge|
  if edge['origin_onestop_id'] != edge['destination_onestop_id']
    key         = "#{edge['origin_onestop_id']},#{edge['destination_onestop_id']}"
    edges[key] += 1
  end
end

# Now that we know the number of occurrences of each edge,
# pass through them again to create their properties for an eventual GeoJSON output
edges.each do |edge_key,edge_value|
  origin_id, destination_id = edge_key.split(",")

  origin      = reader.get_stop(origin_id)
  destination = reader.get_stop(destination_id)

  origin_coordinates      = origin["geometry"]["coordinates"]
  destination_coordinates = destination["geometry"]["coordinates"]
  coordinates             = [ origin_coordinates, destination_coordinates ]

  frequency  = edge_value / WINDOW_LENGTH_IN_HOURS
  width      = 2.5
  if frequency > 12
    color = '#d7301f'
  elsif frequency > 8
    color = '#fc8d59'
  elsif frequency > 0
    color = '#fdcc8a'
  end

  properties = { "origin_onestop_id"      => origin_id,
                 "destination_onestop_id" => destination_id,
		 "frequency"              => frequency,
                 "trips"                  => edge_value,
		 "stroke-width"           => width,
		 "stroke"                 => color
	       }
  feature = { type: 'Feature',
              properties: properties,
	      geometry: {
	        type: 'LineString',
		coordinates: coordinates
	      }
	    }

  if origin["imported_from_feed_onestop_ids"].include?(SUBWAY_ONESTOP_ID) && destination["imported_from_feed_onestop_ids"].include?(SUBWAY_ONESTOP_ID)
    features[:subway] << feature
  else
    features[:bus] << feature
  end
  features[:both] << feature
end

# Create the output directory if it does not exist
Dir.mkdir(OUTPUT_DIR) if OUTPUT_DIR && !File.exist?(OUTPUT_DIR)

# Iterate through the types of feature sets
features.each do |key, feature_array|

  # Output the GeoJSON results to a file
  filename = "#{OUTPUT_DIR}/output_#{DEFAULT_DATE}_#{DEFAULT_TIME_FRAME.gsub(':','-').split(',').join('_')}_#{key.to_s}.geojson"

  File.open(filename, 'w') do |f|
    f.write JSON.generate({type: 'FeatureCollection', features: feature_array })
  end

end
