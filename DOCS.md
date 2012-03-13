##Dependency
* Redis

The **DulyNoted** module contains five main methods:

* `track`
* `update`
* `query`
* `count`
* `chart`

##Parameter Descriptions
`metric_name`: The name of the metric to track, ex: `page_views`, `downloads`

`for`: A name space for your metric, ex: `home_page`
*New in v1.0.0*: `for` can be an array of nested contexts.  For example, say you had users, and users had videos, and you wanted to track plays.  Your `for` might look like `["user_1", "video_6"]`.  Now when you're doing `count`s or `quer`ies, you can specify just `for: "user_1"` to get all of the plays for user_1's videos, or you can specify `for: ["user_1", "video_6"]` to get just that video's plays.  It is important to note that `for`s are nested, so you cannot ask for a count `for: "video_6"`, it must always be referenced through `user_1`.

`generated_at`: If the metric was generated in the past but is just now being logged, you can set the time it was generated at

`meta`: A hash with whatever meta data fields you might want to store, ex: `ip_address`, `file_type`

`meta_fields`: An array of fields to retrieve from the meta hash.  If not specified, the entire hash will be grabbed.  Fields will be converted to strings, because redis converts all hash keys and values to strings.

`time_start`: The start of the time range to grab the data from.  **Important:**  `time_start` should always be the time farthest in the past.

`time_end`: The end of the time range to grab the data from.  **Important:** `time_end` should always be the time closest to the present.

`time_range`: A Range object made up of two Time objects.  The beginning of the Range should be farthest in the past, and the end of the range should be closest to the present.  If `time_range` is defined, `time_end` and `time_start` do not need to be.



##Track

_parameters: `metric_name`, `for`(optional), `generated_at`(optional), `meta`(optional)_

_returns: `id` for editing metadata_

Use track to track an event, like a page view, or a download.  Use the `for` option to give an event a context.  For instance, for page views, you might set `for` to `home_page`, so that you know which page was viewed.  You can also store metadata along with your metric with the `meta` hash.

###Usage

	DulyNoted.track("page_views", for: "home", meta: {browser: "chrome"})
	
	DulyNoted.track("video_plays", for: ["user_7261", "video_917216"], meta: {amount_watched: 0})
	
	DulyNoted.track("purchases", for: "user_281", generated_at: 1.day.ago)



##Update

_parameters: `id`, `meta`(optional)_

Use update to add, or edit the metadata stored with a metric.

###Usage

	DulyNoted.track("page_views", meta: {time_on_page: 0, browser: "chrome"}) # => 5673
	
    DulyNoted.update(5673, meta: { time_on_page: 30 })



##Query

_parameters: `metric_name`, `for`(optional), `meta_fields`(optional), `time_start`(optional), `time_end`(optional), `time_range`(optional)_

Query will return an array of all the metadata in chronological order from a time range, or for the whole data set.  If for is specified, it will limit it by that context.  For instance, if you have `track`ed several page views with `for` set to the name of the page that was viewed, you could query with `for` set to `home_page` to get all of the metadata from the page views from the home page, or you could leave off the `for`, and return all of the metadata for all of the page views, across all pages.


###Usage

    DulyNoted.query("page_views",
      for: "home_page",
      time_start: 1.day.ago,
      time_end: Time.now)

##Count

_parameters: `metric_name`, `for`(optional), `time_start`(optional), `time_end`(optional), `time_range`(optional)_

Count will return the number of events logged in a given time range, or if no time range is given, the total count.  As with `#query`, you can specify `for` to return a subset of counts, or you can leave it off to get the count across the whole `metric_name`.

###Usage

    DulyNoted.count("page_views",
      for: "home_page",
      time_start: 1.day.ago,
      time_end: Time.now)
      

##Chart

_parameters: `metric_name`, `data_points`(required),`for`(optional), `time_start`(optional), `time_end`(optional), `time_range`(optional)_

Chart is a little complex, but I'll try to explain all of the possibilities.  It's main purpose is to pull out your data and prepare it in a way that makes it easy to chart.  The smallest amount of input it will take is just a `metric_name` and an amount of `data_points` to capture.  This will check the time of the earliest known data point, and the time of the last known data point, and run chart with those values as the `time_start` and `time_end` respectively.  It will take the amount of time that that spans, and divide it by the number of data points you asked for, and will split the time up evenly, and return a hash of times, and counts.  If you specify both a `time_start` and a `time_end`, and a number of `data_points`, then it will divide the amount of time that that spans and will return a hash of times and counts.  The other option is that you can specify either a `time_start` OR a `time_end` and a `step` and a number of `data_points`.  This will start at whatever time you specified, and (if it's `time_end`) count down by the step (if you specified `time_start`, it would count up), as many times as the number of data points you requested.

###Usage

	DulyNoted.chart("page_views",
		:time_range => 1.month.ago..Time.now,
		:step => 1.day)
		
	DulyNoted.chart("page_views",
		:time_range => 1.day.ago..Time.now,
		:data_points => 12)
		
	DulyNoted.chart("page_views",
		:time_start => 1.day.ago,
		:step => 1.hour,
		:data_points => 12)
		
	DulyNoted.chart("downloads",
		:time_end => Time.now,
		:step => 1.month,
		:data_points => 12)
		
	DulyNoted.chart("page_views",
		:data_points => 100)
	

Chart can be a little confusing but it's pretty powerful, so play around with it.

##Magic

###count_x_by_y

If you want to count a number of events by a meta field, you can use this magic command.  So imagine this scenario:

	DulyNoted.track("page_views", meta: {browser: "chrome"})
	
And you wanted to see a break down of page views by various browsers, you can call `DulyNoted.count_page_views_by_browser` and you'd get a hash that looked something like this:

	{"chrome" => 2913, "firefox" => 5281, "IE" => 7182, "safari" => 3213}

So that method will work as soon as you've tracked something with that metric name.  If you try to call the method on a metric that you haven't yet tracked you will get a `DulyNoted::NotValidMetric`.  But if you reference a meta field that didn't exist, you'd just get a hash that looks like

	{nil => 1}
	
##Behind the curtain (metaprogramming)

###method_missing

As I'm sure you're aware, method_missing is the magic tool for ruby developers to define dynamic methods like the above `count_x_by_y`, which is exactly what we use it for.


##Redis

DulyNoted will try to connect to Redis's default url and port if you don't specify a Redis connection URL. You can set the url with the method

    DulyNoted.redis = REDIS_URL

