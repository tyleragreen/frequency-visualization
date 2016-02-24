#----------------------------------------------------
#
# Classes to read from the Transitland API
#
# Author: Tyler Green (greent@tyleragreen.com)
#
#----------------------------------------------------

require 'ostruct'

#----------------------------------------------------
# TimeFrame
#
# Class to hold a time frame and return it in
# different formats
#----------------------------------------------------
class TimeFrame

  SECONDS_PER_HOUR = 3600

  def initialize(start_time, end_time)
    @start_time = start_time
    @end_time   = end_time
  end

  def get_date
    return @start_time.strftime("%Y-%m-%d")
  end

  def get_length
    return (@end_time - @start_time) / SECONDS_PER_HOUR
  end

  def get_api_format
    return "#{@start_time.strftime("%H:%M:%S")},#{@end_time.strftime("%H:%M:%S")}"
  end

  def get_filename_format
    return get_api_format.gsub(':','-').split(',').join('_')
  end
end

#----------------------------------------------------
# BoundingBox
#
# Class to hold coordinates of a bounding box and
# return it in different formats
#----------------------------------------------------
class BoundingBox
  def initialize(coordinates)
    @coordinates = coordinates
  end

  def get_api_format
    return @coordinates.join(',')
  end

  def get_filename_format
    return @coordinates.join('_').gsub('.','o')
  end
end

#----------------------------------------------------
# TransitlandAPIReader
#
# Class to handle reads of the Transitland API
#----------------------------------------------------
class TransitlandAPIReader

  HOSTNAME      = "https://transit.land/api/v1/"
  CACHE_DIR     = "cache"
  PER_PAGE      = 1000
  EXTENSION     = "json"
  FILENAME_ARGS = [ :bounding_box,
                    :date,
		    :time_frame ]

  #----------------------------------------------------
  # Set up instance variables of a TransitlandAPIReader object
  def initialize(bounding_box, time_frame)
    @bounding_box = bounding_box
    @time_frame   = time_frame
    @date         = @time_frame.get_date
  end

  #----------------------------------------------------
  # Fetch JSON data from a given URL, save attributes with
  # a given field name, and handle pagination (Transitland-specific)
  def get_json_data_from_api(url, field)
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
  # Get JSON data, deciding on the fly whether to fetch
  # it from the API or use the local cache
  def get_json_data(filename, url, endpoint)
    if File.exist?(filename)
      file_contents = File.readlines(filename)[0]
      json_data     = JSON.parse(file_contents)
    else
      json_data = get_json_data_from_api(url, endpoint)

      # Create the cache directory if it does not exist
      Dir.mkdir(CACHE_DIR) if CACHE_DIR && !File.exist?(CACHE_DIR)
      File.open(filename, 'w') do |f|
        f.write JSON.generate(json_data)
      end
    end
    
    return json_data
  end

  #----------------------------------------------------
  # Get a filename used for the local cache that is unique
  # based on the request type and options
  def get_cache_filename(endpoint, args)

    filename = "#{CACHE_DIR}/#{endpoint}"

    FILENAME_ARGS.each do |arg|
      filename += "_#{args[arg]}" if args[arg]
    end

    filename += ".#{EXTENSION}"

    return filename
  end

  #----------------------------------------------------
  # Fetch the schedule_stop_pair list for the given time and bounding box
  def get_schedule_stop_pairs
    endpoint = "schedule_stop_pairs"

    url  = "#{HOSTNAME}#{endpoint}?"
    url += "per_page=#{PER_PAGE}&bbox=#{@bounding_box.get_api_format}&date=#{@date}&origin_departure_between=#{@time_frame.get_api_format}"

    filename  = get_cache_filename(endpoint, bounding_box: @bounding_box.get_filename_format,
                                             date:         @date,
                                             time_frame:   @time_frame.get_filename_format)

    return get_json_data(filename, url, endpoint)
  end

  #----------------------------------------------------
  # Iterate through the stop pairs (transit route between two stops that departed in the specified time frame)
  # and count the number of times each edge occurs to begin to tabulate frequency
  def get_edges
    edges            = {}
    edges.default    = 0

    get_schedule_stop_pairs.each do |edge|
      if edge['origin_onestop_id'] != edge['destination_onestop_id']
        key         = [ edge['origin_onestop_id'], edge['destination_onestop_id'] ]
        edges[key] += 1
      end
    end

    return edges
  end

  #----------------------------------------------------
  # Fetch the stops in the given bounding box
  def get_stops
    endpoint = "stops"

    url       = "#{HOSTNAME}#{endpoint}?per_page=#{PER_PAGE}&bbox=#{@bounding_box.get_api_format}"
    filename  = get_cache_filename(endpoint, bounding_box: @bounding_box.get_filename_format)

    json_data = get_json_data(filename, url, endpoint)

    stop_hash = {}
    json_data.each do |stop_data|
      stop = OpenStruct.new(stop_data)
      stop_hash[stop.onestop_id] = stop
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
