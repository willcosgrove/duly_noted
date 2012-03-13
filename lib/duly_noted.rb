# Duly noted is a redis backed stats and metrics tracker.  It works as follows:
# 
#     DulyNoted.track("page_views",
#       for: "home_page")
# 
# This would log one page view for the home page.  Then to see how many page views the home page has gotten, you would simply call:
# 
#     DulyNoted.count("page_views",
#       for: "home_page")
# 
# You can also store meta data with your metrics by passing your data in a hash to the `meta` key like so:
# 
#     DulyNoted.track("page_views",
#       for: "home_page",
#       meta: {
#         user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2)...",
#         ip_address: "128.194.3.138"
#       })
# 
# If the metric was generated in the past but is just now being logged, you can alter it's time stamp with the `generated_at` key:
# 
#     DulyNoted.track("page_views",
#       for: "home_page",
#       generated_at: 10.minutes.ago)
# 
# To get the count for a particular time range, you can use the `time_start` and `time_end` keys in the count call like so:
# 
#     DulyNoted.count("page_views",
#       for: "home_page",
#       time_start: 1.day.ago,
#       time_end: Time.now)
# 
# This will return the page view count for the home page for the past day.
#
# You can also just specify a `time_range` like so:
#
#     DulyNoted.count("page_views",
#       for: "homepage",
#       time_range: 1.day.ago..Time.now)

# ##Dependency
# * Redis

require "redis"
require "uri"
require "duly_noted/helpers"
require "duly_noted/version"
require "duly_noted/updater"
require 'duly_noted/configuration'

# The **DulyNoted** module contains five main methods:

# * `track`
# * `update`
# * `query`
# * `count`
# * `chart`

module DulyNoted
  include Helpers
  include Updater
  include Configuration
  extend self # the following are class methods

# ##Parameter Descriptions
# `metric_name`: The name of the metric to track, ex: `page_views`, `downloads`
# 
# `for`: A name space for your metric, ex: `home_page`
# *New in v1.0.0*: `for` can be an array of nested contexts.  For example, say you had users, and users had videos, and you wanted to track plays.  Your `for` might look like `["user_1", "video_6"]`.  Now when you're doing `count`s or `quer`ies, you can specify just `for: "user_1"` to get all of the plays for user_1's videos, or you can specify `for: ["user_1", "video_6"]` to get just that video's plays.  It is important to note that `for`s are nested, so you cannot ask for a count `for: "video_6"`, it must always be referenced through `user_1`.
# 
# `generated_at`: If the metric was generated in the past but is just now being logged, you can set the time it was generated at
# 
# `meta`: A hash with whatever meta data fields you might want to store, ex: `ip_address`, `file_type`
# 
# `meta_fields`: An array of fields to retrieve from the meta hash.  If not specified, the entire hash will be grabbed.  Fields will be converted to strings, because redis converts all hash keys and values to strings.
# 
# `time_start`: The start of the time range to grab the data from.  **Important:**  `time_start` should always be the time farthest in the past.
# 
# `time_end`: The end of the time range to grab the data from.  **Important:** `time_end` should always be the time closest to the present.
# 
# `time_range`: A Range object made up of two Time objects.  The beginning of the Range should be farthest in the past, and the end of the range should be closest to the present.  If `time_range` is defined, `time_end` and `time_start` do not need to be.

  #   ##Track

  # _parameters: `metric_name`, `for`(optional), `generated_at`(optional), `meta`(optional)_
  #
  # _returns: `id` for editing metadata_
  #  
  # Use track to track an event, like a page view, or a download.  Use the `for` option
  # to give an event a context.  For instance, for page views, you might set `for` to
  # `home_page`, so that you know which page was viewed.  You can also store metadata
  # along with your metric with the `meta` hash.
  # 
  # ###Usage

  #     DulyNoted.track("page_views",
  #       for: "home",
  #       meta: {browser: "chrome"})
  # 
  #     DulyNoted.track("video_plays",
  #       for: ["user_7261", "video_917216"],
  #       meta: {amount_watched: 0})
  # 
  #     DulyNoted.track("purchases",
  #       for: "user_281",
  #       generated_at: 1.day.ago)
    
  def track(metric_name, options={})
    options = {:generated_at => Time.now}.merge(options)
    key = build_key(metric_name)
    key_without_for = key.dup
    id = DulyNoted.redis.incr "dnid"
    key << assemble_for(options)
    DulyNoted.redis.pipelined do
      DulyNoted.redis.sadd build_key("metrics", false), key_without_for
      DulyNoted.redis.zadd key, options[:generated_at].to_f, "#{key}:#{id}:meta"
      DulyNoted.redis.set "dnid:#{id}", "#{key}:#{id}:meta" # set alias key
      DulyNoted.redis.expire "dnid:#{id}", DulyNoted::Configuration.editable_for
      if options[:meta] # set meta data
        DulyNoted.redis.mapped_hmset "#{key}:#{id}:meta", options[:meta]
        options[:meta].keys.each do |field|
          DulyNoted.redis.sadd "#{key}:fields", field
        end
      end
    end
    id
  end
  
  #   ##Update
  # 
  # _parameters: `id`, `meta`(optional)_
  # 
  # Use update to add, or edit the metadata stored with a metric.
  # 
  # ###Usage
  # 
  #     DulyNoted.track("page_views",
  #       meta: {time_on_page: 0, browser: "chrome"}) # => 5673
  #     DulyNoted.update(5673,
  #       meta: { time_on_page: 30 })
  
  def update(id, options={})
    key = "dnid:#{id}"
    real_key = DulyNoted.redis.get key
    raise InvalidId if real_key == nil
    DulyNoted.redis.mapped_hmset real_key, options[:meta] if options[:meta] 
  end
  
  # ##Query
  # 
  # _parameters: `metric_name`, `for`(optional), `meta_fields`(optional), `time_start`(optional), `time_end`(optional), `time_range`(optional)_
  # 
  # Query will return an array of all the metadata in chronological order from a time range, or for the whole data set.  If for is specified, it will limit it by that context.  For instance, if you have `track`ed several page views with `for` set to the name of the page that was viewed, you could query with `for` set to `home_page` to get all of the metadata from the page views from the home page, or you could leave off the `for`, and return all of the metadata for all of the page views, across all pages.
  # 
  # 
  # ###Usage
  # 
  #     DulyNoted.query("page_views",
  #       for: "home_page",
  #       time_start: 1.day.ago,
  #       time_end: Time.now)
  
  def query(metric_name, options={})
    key = build_key(metric_name)
    parse_time_range(options)
    key << assemble_for(options)
    if options[:id]
      key = "dnid:#{options[:id]}"
      real_key = DulyNoted.redis.get key
      if options[:meta_fields]
        options[:meta_fields].collect! { |x| x.to_s }
        result = {}
        options[:meta_fields].each do |field|
          result[field] = DulyNoted.redis.hget real_key, field
        end
        results = [result]
      else
        results = [DulyNoted.redis.hgetall(real_key)]
      end
    else
      keys = find_keys(key)
      grab_results = Proc.new do |metric|
        if options[:meta_fields]
          options[:meta_fields].collect! { |x| x.to_s }
          result = {}
          options[:meta_fields].each do |field|
            result[field] = DulyNoted.redis.hget metric, field
          end
          result
        else
          DulyNoted.redis.hgetall metric
        end
      end
      results = []
      if options[:time_start] && options[:time_end]
        keys.each do |key|
          results += DulyNoted.redis.zrangebyscore(key, options[:time_start].to_f, options[:time_end].to_f).collect(&grab_results)
        end
      else
        keys.each do |key|
          results += DulyNoted.redis.zrange(key, 0, -1).collect(&grab_results)
        end
      end
    end
    return results
  end
  
  # ##Count
  # 
  # _parameters: `metric_name`, `for`(optional), `time_start`(optional), `time_end`(optional), `time_range`(optional)_
  # 
  # Count will return the number of events logged in a given time range, or if no time range is given, the total count.  As with `#query`, you can specify `for` to return a subset of counts, or you can leave it off to get the count across the whole `metric_name`.
  # 
  # ###Usage
  # 
  #     DulyNoted.count("page_views",
  #       for: "home_page",
  #       time_start: 1.day.ago,
  #       time_end: Time.now)
  
  def count(metric_name, options={})
    parse_time_range(options)
    key = build_key(metric_name)
    key << assemble_for(options)
    keys = find_keys(key)
    sum = 0
    if options[:time_start] && options[:time_end]
      keys.each do |key|
        sum += DulyNoted.redis.zcount(key, options[:time_start].to_f, options[:time_end].to_f)
      end
      return sum
    else
      keys.each do |key|
        sum += DulyNoted.redis.zcard(key)
      end
      return sum
    end
  end

  # ##Chart
  # 
  # _parameters: `metric_name`, `data_points`(required),`for`(optional), `time_start`(optional), `time_end`(optional), `time_range`(optional)_
  # 
  # Chart is a little complex, but I'll try to explain all of the possibilities.  It's main purpose is to pull out your data and prepare it in a way that makes it easy to chart.  The smallest amount of input it will take is just a `metric_name` and an amount of `data_points` to capture.  This will check the time of the earliest known data point, and the time of the last known data point, and run chart with those values as the `time_start` and `time_end` respectively.  It will take the amount of time that that spans, and divide it by the number of data points you asked for, and will split the time up evenly, and return a hash of times, and counts.  If you specify both a `time_start` and a `time_end`, and a number of `data_points`, then it will divide the amount of time that that spans and will return a hash of times and counts.  The other option is that you can specify either a `time_start` OR a `time_end` and a `step` and a number of `data_points`.  This will start at whatever time you specified, and (if it's `time_end`) count down by the step (if you specified `time_start`, it would count up), as many times as the number of data points you requested.
  # 
  # ###Usage
  # 
  #   DulyNoted.chart("page_views",
  #     :time_range => 1.month.ago..Time.now,
  #     :step => 1.day)
  # 
  #   DulyNoted.chart("page_views",
  #     :time_range => 1.day.ago..Time.now,
  #     :data_points => 12)
  # 
  #   DulyNoted.chart("page_views",
  #     :time_start => 1.day.ago,
  #     :step => 1.hour,
  #     :data_points => 12)
  # 
  #   DulyNoted.chart("downloads",
  #     :time_end => Time.now,
  #     :step => 1.month,
  #     :data_points => 12)
  # 
  #   DulyNoted.chart("page_views",
  #     :data_points => 100)
  # 
  # 
  # Chart can be a little confusing but it's pretty powerful, so play around with it.

  def chart(metric_name, options={})
    parse_time_range(options)
    chart = Hash.new(0)
    if options[:time_start] && options[:time_end]
      time = options[:time_start]
      if options[:data_points]
        total_time = options[:time_end] - options[:time_start]
        options[:step] = total_time.to_i / options[:data_points]
      end
      while time < options[:time_end]
        chart[time.to_i] = DulyNoted.count(metric_name, :time_start => time, :time_end => time+options[:step], :for => options[:for])
        time += options[:step]
      end
    elsif options[:step] && options[:data_points] && (options[:time_end] || options[:time_start])
      raise InvalidStep if options[:step] == 0
      options[:step] *= -1 if (options[:step] > 0 && options[:time_end]) || (options[:step] < 0 && options[:time_start])
      time = options[:time_start] || options[:time_end]
      step = options[:step]
      options[:data_points].times do
        options[:time_start] = time
        options[:time_start] += step if step < 0
        options[:time_end] = time
        options[:time_end] += step if step > 0
        chart[time.to_i] = DulyNoted.count(metric_name, options)
        time += step
      end
    elsif options[:data_points]
      key = build_key(metric_name)
      key << assemble_for(options)
      options[:time_start] = Time.at(DulyNoted.redis.zrange(key, 0, 0, :withscores => true)[1].to_f)
      options[:time_end] = Time.at(DulyNoted.redis.zrevrange(key, 0, 0, :withscores => true)[1].to_f)
      chart = DulyNoted.chart(metric_name, options)
    else
      raise InvalidOptions
    end
    return chart
  end

  # ##Magic
  # 
  # ###count_x_by_y
  # 
  # If you want to count a number of events by a meta field, you can use this magic command.  So imagine this scenario:
  # 
  #   DulyNoted.track("page_views", meta: {browser: "chrome"})
  # 
  # And you wanted to see a break down of page views by various browsers, you can call `DulyNoted.count_page_views_by_browser` and you'd get a hash that looked something like this:
  # 
  #   {"chrome" => 2913, "firefox" => 5281, "IE" => 7182, "safari" => 3213}
  # 
  # So that method will work as soon as you've tracked something with that metric name.  If you try to call the method on a metric that you haven't yet tracked you will get a `DulyNoted::NotValidMetric`.  But if you reference a meta field that didn't exist, you'd just get a hash that looks like
  # 
  #   {nil => 1}

  def count_x_by_y(metric_name, meta_field, options)
    options ||= {}
    options = {:meta_fields => [meta_field]}.merge(options)
    meta_hashes = query(metric_name, options)
    result = Hash.new(0)
    meta_hashes.each do |meta_hash|
      result[meta_hash[meta_field]] += 1
    end
    result
  end

  # ##Behind the curtain (metaprogramming)
  # 
  # ###method_missing
  # 
  # As I'm sure you're aware, method_missing is the magic tool for ruby developers to define dynamic methods like the above `count_x_by_y`, which is exactly what we use it for.

  def method_missing(method, *args, &block)
    if method.to_s =~ /^count_(.+)_by_(.+)$/
      count_x_by_y($1, $2, args[0])
    else
      super
    end
  end
  
  # ##Redis
  # 
  # DulyNoted will try to connect to Redis's default url and port if you don't specify a Redis connection URL. You can set the url with the method
  # 
  #     DulyNoted.redis = REDIS_URL
  
  def redis=(url)
    @redis = nil
    @redis_url = url
    redis
  end

  def redis
    @redis ||= (
      url = URI(@redis_url || "redis://127.0.0.1:6379/0")

      check_schema(Redis.new({
        :host => url.host,
        :port => url.port,
        :db => url.path[1..-1],
        :password => url.password
      }))
    )
  end

  def configure
    yield DulyNoted::Configuration
  end

  class NotValidMetric < StandardError; end
  class InvalidOptions < StandardError; end
  class InvalidStep < StandardError; end
  class InvalidId < StandardError; end
  class UpdateError < StandardError; end
end
