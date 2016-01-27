#!/usr/bin/ruby

# Author: Tyler Green (greent@tyleragreen.com)

require 'net/http'
require 'json'
require 'rgeo/geo_json'
require 'openssl'

$stdout.sync = true

DEFAULT_DATE       = "2016-01-22"
DEFAULT_TIME_FRAME = "09:00:00,09:10:00"

NYC_BOX = [ -80.0, 35.0,
            -73.0, 41.0 ]
COLOR_MAP = { 0  => '#fef0d9',
              3  => '#fdcc8a',
	      6  => '#fc8d59',
	      10 => '#d7301f' 
	    }
STROKE_OPACITY = 1.0

class TransitlandAPIReader

  HOSTNAME           = "https://transit.land/api/v1/"
  PER_PAGE           = 1000

  def initialize(bounding_box, date, time_frame)
    @bounding_box = bounding_box
    @date         = date
    @time_frame   = time_frame
  end

  def get_json_data(url, field)
    results = {}
    data    = []

#    begin
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

#    end while url = results["meta"]["next"]
    
    return data
  end

  def get_schedule_stop_pairs
    pairs_url  = "#{HOSTNAME}schedule_stop_pairs?"
    pairs_url += "per_page=#{PER_PAGE}&bbox=#{@bounding_box.join(',')}&date=#{@date}&origin_departure_between=#{@time_frame}"
    return get_json_data(pairs_url, "schedule_stop_pairs")
  end

  def get_stops
    stops_url  = "#{HOSTNAME}stops?per_page=#{PER_PAGE}&bbox=#{@bounding_box.join(',')}"
    stop_array = get_json_data(stops_url, "stops")

    stop_hash = {}
    stop_array.each do |stop|
      stop_hash[stop["onestop_id"]] = stop
    end

    return stop_hash
  end

  def get_stop(onestop_id)

    # Lookup the stops the first time this is called
    unless @stops
      @stops = get_stops
    end

    return @stops[onestop_id]
  end

end

reader = TransitlandAPIReader.new(NYC_BOX, DEFAULT_DATE, DEFAULT_TIME_FRAME)

dir  = "output"
Dir.mkdir(dir) if !File.exist?(dir)
file = File.open("#{dir}/output.geojson",'w')
=begin
pairs = reader.get_schedule_stop_pairs

edges         = {}
edges.default = 0
pairs.each do |edge|
  key         = "#{edge['origin_onestop_id']},#{edge['destination_onestop_id']}"
  edges[key] += 1
end
=end
features = []
#file.puts '{"type":"FeatureCollection","features":['
@geo_factory = RGeo::Cartesian.simple_factory(srid: 4326)
@entity_factory = RGeo::GeoJSON::EntityFactory.instance
#edges.each do |edge_key,edge_value|
puts "getting"
reader.get_stops.each do |key,val|
puts "STOP #{key}"
#  origin_id, destination_id = edge_key.split(",")
=begin
  origin      = reader.get_stop(origin_id)
  destination = reader.get_stop(destination_id)

  origin_coordinates      = origin["geometry"]["coordinates"].join(',')
  destination_coordinates = destination["geometry"]["coordinates"].join(',')

  frequency  = edge_value / (1.to_f/6.to_f)
  freq_class = COLOR_MAP.keys.find { |x| frequency >= x }
=begin
  feature_str = '{ "type"    : "Feature",
		   "properties": { "origin_onestop_id"      : "' + origin_id + '",
		                   "destination_onestop_id" : "' + destination_id + '",
				   "trips"                  : ' + edge_value.to_s + ',
				   "frequency"              : ' + frequency.to_s + ',
				   "stroke"                 : "' + COLOR_MAP[freq_class] + '",
				   "stroke-width"           : ' + freq_class.to_s + ',
				   "stroke-opacity"         : ' + STROKE_OPACITY.to_s + ' },
                   "geometry": { "type"       : "LineString",
	                         "coordinates": [ [' + origin_coordinates + '],
				                  [' + destination_coordinates + '] ] }
	         },'
=end
#  file.puts feature_str
#  feature = RGeo::GeoJSON.decode(feature_str, json_parser: :json)
  object = @entity_factory.feature(@geo_factory.point(10,20),nil,:prop1 => "foo", :prop2 => "bar")
#  feature = RGeo::GeoJSON.encode(object)
#  puts "f: #{feature}"
  features << object#feature
end
#file.puts "]}"
#features = RGeo::GeoJSON::FeatureCollection.new(features)
collection = @entity_factory.feature_collection(features)
hash     = RGeo::GeoJSON.encode(collection)
puts "HASH #{hash}"
file.puts hash.to_json
file.close
