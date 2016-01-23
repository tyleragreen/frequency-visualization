#!/usr/bin/ruby

require 'net/http'
require 'json'

url = "http://transit.land/api/v1/schedule_stop_pairs"
uri = URI(url)
response = Net::HTTP.get(uri)
results = JSON.parse(response)
puts results.class
