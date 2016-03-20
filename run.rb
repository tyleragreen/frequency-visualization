#!/usr/bin/ruby
#----------------------------------------------------
#
# A script that reads the Transitland API compile a 
# frequency visualization of each consecutive transit
# stops in New York City.
#
# Author: Tyler Green (greent@tyleragreen.com)
#
#----------------------------------------------------
require 'json'
require 'date'
require 'transitland_client'

#----------------------------------------------------
# Constants
#----------------------------------------------------
OUTPUT_DIR        = "output"
START_TIME        = Time.new(2016,01,23,7,45,00)
END_TIME          = Time.new(2016,01,23,8,00,00)
SECONDS_PER_HOUR  = 3600
SUBWAY_ONESTOP_ID = "f-dr5r-nyctsubway"
NYC_COORDINATES   = [ -74.5, 40.0,
                      -73.0, 41.0 ]
LINE_WIDTH        = 2.5
COLORS            = { light:  { frequency: 0,
                                color:     '#fdcc8a',
                                width:     2
                              },
                      medium: { frequency: 3,
                                color:     '#fc8d59',
                                width:     4,
                              },
                      heavy:  { frequency: 8,
                                color:     '#d7301f',
                                width:     6
                              },
                    }

#----------------------------------------------------
# Iterate through the stop pairs (transit route between two stops that departed in the specified time frame)
# and count the number of times each edge occurs to begin to tabulate frequency
def get_edges(pairs)
  edges            = {}
  edges.default    = 0

  pairs.each do |edge|
    origin_id      = edge.get(:origin_onestop_id)
    destination_id = edge.get(:destination_onestop_id)
    
    if origin_id != destination_id
      key         = [ origin_id, destination_id ]
      edges[key] += 1
    end
  end

  return edges
end

#----------------------------------------------------
# Calculate the length of the time frame to calculate frequency
def get_time_frame_length
  return (END_TIME - START_TIME) / SECONDS_PER_HOUR
end

#----------------------------------------------------
# Return the date in a format used by the output file names
def get_date
  return START_TIME.strftime("%Y-%m-%d")
end

#----------------------------------------------------
# Main script flow
#----------------------------------------------------
features   = { :bus => [], :subway => [] }
date       = START_TIME.strftime("%Y-%m-%d")
time_frame = "#{START_TIME.strftime("%H:%M:%S")},#{END_TIME.strftime("%H:%M:%S")}"
time_frame_url = time_frame.gsub(':','-').split(',').join('_')

# Fetch from the API a list of all edges between any
# two consecutive transit stops
pairs = TransitlandClient::ScheduleStopPair.find_by(bbox: NYC_COORDINATES.join(','),
                                                    date: date,
                                                    origin_departure_between: time_frame)
# Pre-fetch all the stops within our bounding box so that the individual lookup
# inside the edge loop are faster
stops = TransitlandClient::Stop.find_by(bbox: NYC_COORDINATES.join(','))

# Convert the schedule stop pairs into edges with weights for occurences in the
# given time frame
edges = get_edges(pairs)

# Now that we know the number of occurrences of each edge,
# pass through them again to create their properties for an eventual GeoJSON output
edges.each do |edge_key,edge_value|
  origin_id, destination_id = edge_key
  
  origin      = TransitlandClient::Stop.find_by(onestop_id: origin_id).first
  destination = TransitlandClient::Stop.find_by(onestop_id: destination_id).first

  origin_coordinates      = origin.get(:geometry)["coordinates"]
  destination_coordinates = destination.get(:geometry)["coordinates"]
  coordinates             = [ origin_coordinates, destination_coordinates ]

  frequency  = edge_value / get_time_frame_length
  color = width = nil

  # You are ensured to find a color, as the lowest key is 0
  COLORS.each do |key,properties|
    if frequency > properties[:frequency]
      color = properties[:color]
      width = properties[:width]
    end
  end

  # Remove the Long Island Railroad entries to declutter the map
  feeds = origin.get(:imported_from_feed_onestop_ids) & destination.get(:imported_from_feed_onestop_ids)
  next if feeds.include?("f-dr5-mtanyclirr")

  # Construct the properties for this GeoJSON feature
  properties = { origin_onestop_id:      origin_id,
                 destination_onestop_id: destination_id,
                 frequency:              frequency,
                 trips:                  edge_value,
                 'stroke-width' =>       width,
                 stroke:                 color,
                 description:            "Frequency: #{frequency.to_i} trips / hour",
                 title:                  "#{origin.get(:name)} to #{destination.get(:name)}"
               }

  # Add the properties and coordinates to a new GeoJSON feature
  feature = { type:       'Feature',
              properties: properties,
              geometry: { type:        'LineString',
                          coordinates: coordinates
                        }
            }

  # Group the feeds by bus or subway, to be shown independently in the web view
  if feeds.include?(SUBWAY_ONESTOP_ID)
    features[:subway] << feature
  else
    features[:bus] << feature
  end
end

Dir.mkdir(OUTPUT_DIR) if OUTPUT_DIR && !File.exist?(OUTPUT_DIR)

# Iterate through the types of feature sets
features.each do |key, feature_array|

  # Output the GeoJSON results to a file
  filename = "#{OUTPUT_DIR}/output_#{get_date}_#{time_frame_url}_#{key.to_s}.geojson"

  File.open(filename, 'w') do |f|
    f.write JSON.generate({type: 'FeatureCollection', features: feature_array })
  end

end
