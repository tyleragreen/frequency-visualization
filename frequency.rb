#!/usr/bin/ruby

require 'net/http'
require 'json'
require 'rgeo/geo_json'
$stdout.sync = true
url = "https://transit.land/api/v1/schedule_stop_pairs?per_page=500&date=2016-01-22&bbox=-80.0,35.0,-73.0,41.0&origin_departure_between=09:00:00,09:10:00"
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
#puts "RESPONSE #{response.body}"
results = JSON.parse(response.body)
#puts "RESULTS #{results["schedule_stop_pairs"]}"
pairs += results["schedule_stop_pairs"]
puts pairs.length
end while url = results["meta"]["next"]

edges = {}
stops = {}
edges.default = 0
results["schedule_stop_pairs"].each do |edge|
  key = "#{edge['origin_onestop_id']},#{edge['destination_onestop_id']}"
  edges[key] += 1
end
stops_url = "http://transit.land/api/v1/stops?per_page=20&bbox=-121.0,35.0,-73.0,41.0"
uri = URI(stops_url)
response = Net::HTTP.get(uri)
results = JSON.parse(response)
results["stops"].each do |stop|
  stops[stop['onestop_id']] = stop
end
stops.each do |key,value|
  puts "KEY #{key} GEO #{value['geometry']}"
end

f = File.open("output.geojson",'w')

features = []
edges.each do |key,value|
  origin_id, destination_id = key.split(",")
  puts origin_id
  features << RGeo::GeoJSON.decode('{ "type": "Feature", "geometry": { "type": "LineString", "coordinates": [1,1] } }', json_parser: :json)
end
features = RGeo::GeoJSON::FeatureCollection.new(features)
hash = RGeo::GeoJSON.encode(features)
f.puts hash.to_json
