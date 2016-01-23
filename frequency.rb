#!/usr/bin/ruby

# Author: Tyler Green (greent@tyleragreen.com)

require 'net/http'
require 'json'
require 'rgeo/geo_json'
require 'openssl'
$stdout.sync = true

def get_json_data(url, field)
results = {}
pairs = []
begin
puts "URL #{url}"
uri = URI.parse(url)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
request = Net::HTTP::Get.new(uri.request_uri)
response = http.request(request)
results = JSON.parse(response.body)
pairs += results[field]
puts pairs.length
end while url = results["meta"]["next"]

return pairs
end
dir = "output"
Dir.mkdir(dir) if !File.exist?(dir)
f = File.open("#{dir}/output.geojson",'w')
url = "https://transit.land/api/v1/schedule_stop_pairs?per_page=1000&date=2016-01-22&bbox=-80.0,35.0,-73.0,41.0&origin_departure_between=09:00:00,09:10:00"

pairs = get_json_data(url, "schedule_stop_pairs")
puts "PAIRS COUNT #{pairs.length}"
stops_url = "https://transit.land/api/v1/stops?per_page=1000&bbox=-80.0,35.0,-73.0,41.0"
stops = get_json_data(stops_url, "stops")
puts "STOPS COUNT #{stops.length}"
puts "STOPS 1 #{stops[0]["geometry"]["coordinates"]}"
edges = {}
edges.default = 0
pairs.each do |edge|
  key = "#{edge['origin_onestop_id']},#{edge['destination_onestop_id']}"
  edges[key] += 1
end

features = []
edges.each do |key,value|
  origin_id, destination_id = key.split(",")
  puts origin_id
  origin = stops.select { |stop| stop["onestop_id"] == origin_id }[0]
  destination = stops.select { |stop| stop["onestop_id"] == destination_id }[0]
  puts "ORIGIN #{origin}"
  features << RGeo::GeoJSON.decode("{ \"type\": \"Feature\", \"geometry\": { \"type\": \"LineString\", \"coordinates\": [#{origin["geometry"]["coordinates"]},#{destination["geometry"]["coordinates"]}] } }", json_parser: :json)
end
features = RGeo::GeoJSON::FeatureCollection.new(features)
hash = RGeo::GeoJSON.encode(features)
f.puts hash.to_json
