#!/usr/bin/ruby

# Author: Tyler Green (greent@tyleragreen.com)

require 'net/http'
require 'json'
require 'rgeo/geo_json'
require 'openssl'

$stdout.sync = true

class APIReader

  HOSTNAME           = "https://transit.land/api/v1/"
  PER_PAGE           = 1000
  DEFAULT_DATE       = "2016-01-22"
  DEFAULT_TIME_FRAME = "09:00:00,09:10:00"

  NYC_BOX = [ -80.0, 35.0,
              -73.0, 41.0 ]


  def get_json_data(url, field)
    results = {}
    pairs = []
    begin
      puts "URL #{url}"
      uri              = URI.parse(url)
      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request  = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      results  = JSON.parse(response.body)
      pairs   += results[field]
      puts pairs.length

    end while url = results["meta"]["next"]
    
    return pairs
  end

  def get_schedule_stop_pairs(bounding_box=NYC_BOX, date=DEFAULT_DATE, time_frame=DEFAULT_TIME_FRAME)
    pairs_url  = "#{HOSTNAME}schedule_stop_pairs?"
    pairs_url += "per_page=#{PER_PAGE}&bbox=#{bounding_box.join(',')}&date=#{date}&origin_departure_between=#{time_frame}"
    return get_json_data(pairs_url, "schedule_stop_pairs")
  end

  def get_stops(bounding_box=NYC_BOX)
    stops_url = "#{HOSTNAME}stops?per_page=#{PER_PAGE}&bbox=#{bounding_box.join(',')}"
    return get_json_data(stops_url, "stops")
  end

end

reader = APIReader.new

dir  = "output"
Dir.mkdir(dir) if !File.exist?(dir)
file = File.open("#{dir}/output.geojson",'w')

pairs = reader.get_schedule_stop_pairs
puts "PAIRS COUNT #{pairs.length}"
stops = reader.get_stops
puts "STOPS COUNT #{stops.length}"
stops_by_name = {}
stops.each do |stop|
  stops_by_name[stop["onestop_id"]] = stop
end

edges         = {}
edges.default = 0
pairs.each do |edge|
  key = "#{edge['origin_onestop_id']},#{edge['destination_onestop_id']}"
  edges[key] += 1
end

features = []
edges.each do |key,value|
  origin_id, destination_id = key.split(",")

  origin      = stops_by_name[origin_id]
  destination = stops_by_name[destination_id]

  origin_coordinates      = origin["geometry"]["coordinates"].join(',')
  destination_coordinates = destination["geometry"]["coordinates"].join(',')

  feature_str = '{ "type"    : "Feature",
                   "geometry": { "type"       : "LineString",
	                         "coordinates": [ [' + origin_coordinates + '],
				                  [' + destination_coordinates + '] ] } }'
  features << RGeo::GeoJSON.decode(feature_str, json_parser: :json)
end

features = RGeo::GeoJSON::FeatureCollection.new(features)
hash     = RGeo::GeoJSON.encode(features)

file.puts hash.to_json
file.close
