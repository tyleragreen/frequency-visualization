# New York City Transit Frequency Visualization

This script and library uses the [Transitland Datastore](https://github.com/transitland/transitland-datastore) to create a transit frequency visualization for the five boroughs of New York City. The results are visible in `new_york.html` using [Mapbox](https://github.com/mapbox).

## Run Instructions
No gems are required, so simply run `ruby run.rb`.

## Output
Two GeoJSON files are produced for each run, one for subway routes and one for bus (and a few ferry) routes for the date, time, and location specified in `run.rb`. The output follows the [Mapbox simplestyle-spec](https://github.com/mapbox/simplestyle-spec/tree/master/1.1.0) for ease of display.

The four GeoJSON files that are called by `new_york.html` are in the `output` directory. GitHub uses Mapbox, so the intended styling can be seen when previewing these files in GitHub.

## Notes
The TransitlandAPIReader uses a local caching mechanism to store the JSON results of queries to the [Transitland Datastore](https://github.com/transitland/transitland-datastore). A JSON file is created on your local system for each API 'endpoint' and is reused when queried on future runs, given that endpoint's requested options are the same.

## Potential Improvements
- The TransitlandAPIReader class could be generalized into a gem with a decent test suite, similar to one [Transitland used to maintain](https://github.com/transitland/transitland-ruby-client).
- The run.rb script could take a job spec input to produce GeoJSON files for multiple days and cities in a single run.
- The Mapbox front-end could be used to visualize any arbitrary transit system’s GTFS shape data. This would likely be done using a live Ruby on Rails back-end, rather than the offline Ruby script I am currently using.

## Issues
Please contact Tyler at [greent@tyleragreen.com](mailto:greent@tyleragreen.com) or file a GitHub Issue with any ideas or suggestions.
