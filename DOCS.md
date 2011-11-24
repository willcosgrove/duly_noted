##Dependency
* Redis

The **DulyNoted** module contains four main methods:

* `track`
* `update`
* `query`
* `count`

##Track

_parameters: `metric_name`, `for`(optional), `generated_at`(optional), `meta`(optional), `ref_id`(optional)_

`metric_name`: The name of the metric to track, ex: `page_views`, `downloads`

`for`_(optional)_: A name space for your metric, ex: `home_page`

`generated_at`_(optional)_: If the metric was generated in the past but is just now being logged, you can set the time it was generated at

`meta`_(optional)_: A hash with whatever meta data fields you might want to store, ex: `ip_address`, `file_type`

`ref_id`_(optional)_: If you need to reference the metric later, perhaps to add more metadata later on, you can set a reference id that you can use to update the metric

##Update

_parameters: `metric_name`, `ref_id`, `for`(required if set when created), `meta`(optional)_

The meta hash will not overwrite the old meta hash but be merged with it, with the new one overwriting conflicts.

`metric_name`: The name of the metric to update, ex: `page_views`, `downloads`

`ref_id`: The reference ID that you set when you called `track`

`for`_(required if you set `for` when you generated the metric)_: A name space for your metric, ex: `home_page`

`meta`_(optional)_: A hash with whatever meta data fields you might want to store, or update ex: `ip_address`, `file_type`, `time_left`

###Usage

    DulyNoted.update("page_views", "a_unique_id", for: "home_page", meta: { time_on_page: 30 })

##Query

_parameters: `metric_name`, `for`(required if set when created), `time_start`(optional), `time_end`(optional)_

Query will return an array of all the metadata in chronological order from a time range, or for the whole data set.

`metric_name`: The name of the metric to query, ex: `page_views`, `downloads`

`for`_(required if you set `for` when you generated the metric)_: A name space for your metric, ex: `home_page`

`time_start`_(optional)_: The start of the time range to grab the data from.

`time_end`_(optional)_: The end of the time range to grab the data from.

###Usage

    DulyNoted.query("page_views",
      for: "home_page",
      time_start: 1.day.ago,
      time_end: Time.now)

##Count

_parameters: `metric_name`, `for`(required if set when created), `time_start`(optional), `time_end`(optional)_

Count will return the number of events logged in a given time range, or if no time range is given, the total count.

`metric_name`: The name of the metric to query, ex: `page_views`, `downloads`

`for`_(required if you set `for` when you generated the metric)_: A name space for your metric, ex: `home_page`

`time_start`_(optional)_: The start of the time range to grab the data from.

`time_end`_(optional)_: The end of the time range to grab the data from.

###Usage

    DulyNoted.count("page_views",
      for: "home_page",
      time_start: 1.day.ago,
      time_end: Time.now)

##Redis

DulyNoted will try to connect to Redis's default url and port if you don't specify a Redis connection URL. You can set the url with the method

    DulyNoted.redis = REDIS_URL

