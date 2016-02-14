# New York City Transit Frequency Visualization

This script and library uses the [Transitland Datastore](https://github.com/transitland/transitland-datastore) to create a transit frequency visualization for the five boroughs of New York City. The results are presented in `new_york.html` using [Mapbox](https://github.com/mapbox).

## To Run
No gems are required, so simply run `ruby run.rb`.

## Output
Two GeoJSON files are produced, one for subway routes and one for bus (and a few ferry) routes for the date, time, and location specified in `run.rb`. The output follows the [Mapbox simplestyle-spec](https://github.com/mapbox/simplestyle-spec/tree/master/1.1.0) for ease of display.

## Notes
The TransitlandAPIReader uses a local caching mechanism to store the JSON results of queries to the [Transitland Datastore](https://github.com/transitland/transitland-datastore). A JSON file is created on your local system for each API 'endpoint' and is reused when queried on future runs, given that endpoint's requested options are the same.

## Potential improvements:
- The TransitlandAPIReader could be generalized into a gem.
- The run.rb script could take a job spec input to produce GeoJSON files for multiple days and cities (bounding boxes) in a single run.

## Issues
Please contact Tyler at [greent@tyleragreen.com](mailto:greent@tyleragreen.com) or file a GitHub Issue with any ideas or suggestions.
