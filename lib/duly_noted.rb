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

# ##Dependency
# * Redis

require "redis"
require "uri"
require "duly_noted/helpers"
require "duly_noted/version"
require 'pry'

# The **DulyNoted** module contains four main methods:
# 
# * `track`
# * `update`
# * `query`
# * `count`

module DulyNoted
  extend self # the following are class methods
  
  # ##Track
  # 
  # _parameters: `metric_name`, `for`(optional), `generated_at`(optional), `meta`(optional), `ref_id`(optional)_
  # 
  # `metric_name`: The name of the metric to track, ex: `page_views`, `downloads`
  # 
  # `for`_(optional)_: A name space for your metric, ex: `home_page`
  # 
  # `generated_at`_(optional)_: If the metric was generated in the past but is just now being logged, you can set the time it was generated at
  # 
  # `meta`_(optional)_: A hash with whatever meta data fields you might want to store, ex: `ip_address`, `file_type`
  # 
  # `ref_id`_(optional)_: If you need to reference the metric later, perhaps to add more metadata later on, you can set a reference id that you can use to update the metric
    
  def track(metric_name, options={})
    options = {generated_at: Time.now}.merge(options)
    key = normalize(metric_name)
    key << ":#{options[:for]}" if options[:for]
    DulyNoted.redis.zadd key, options[:generated_at].to_f, "#{key}:#{options[:generated_at].to_f}:meta"
    DulyNoted.redis.set "#{key}:#{options[:ref_id]}", "#{key}:#{options[:generated_at].to_f}:meta" if options[:ref_id] # set alias key
    DulyNoted.redis.mapped_hmset "#{key}:#{options[:generated_at].to_f}:meta", options[:meta] if options[:meta] # set meta data
  end
  
  # ##Update
  # 
  # _parameters: `metric_name`, `ref_id`, `for`(required if set when created), `meta`(optional)_
  # 
  # The meta hash will not overwrite the old meta hash but be merged with it, with the new one overwriting conflicts.
  # 
  # `metric_name`: The name of the metric to track, ex: `page_views`, `downloads`
  # 
  # `ref_id`: The reference ID that you set when you called `track`
  # 
  # `for`_(required if you set `for` when you generated the metric)_: A name space for your metric, ex: `home_page`
  # 
  # `meta`_(optional)_: A hash with whatever meta data fields you might want to store, or update ex: `ip_address`, `file_type`, `time_left`
  # 
  # ###Usage
  # 
  #     DulyNoted.update("page_views",
  #       "a_unique_id",
  #       for: "home_page",
  #       meta: { time_on_page: 30 })
  
  def update(metric_name, ref_id, options={})
    key = normalize(metric_name)
    key << ":#{options[:for]}" if options[:for]
    key << ":#{ref_id}"
    real_key = DulyNoted.redis.get key
    DulyNoted.redis.mapped_hmset real_key, options[:meta] if options[:meta] 
  end
  
  # ##Query
  # 
  # _parameters: `metric_name`, `for`(required if set when created), `time_start`(optional), `time_end`(optional)_
  # 
  # Query will return an array of all the metadata in chronological order from a time range, or for the whole data set.
  # 
  # `metric_name`: The name of the metric to query, ex: `page_views`, `downloads`
  # 
  # `for`_(required if you set `for` when you generated the metric)_: A name space for your metric, ex: `home_page`
  # 
  # `time_start`_(optional)_: The start of the time range to grab the data from.
  # 
  # `time_end`_(optional)_: The end of the time range to grab the data from.
  # 
  # ###Usage
  # 
  #     DulyNoted.query("page_views",
  #       for: "home_page",
  #       time_start: 1.day.ago,
  #       time_end: Time.now)
  
  def query(metric_name, options={})
    key = normalize(metric_name)
    key << ":#{options[:for]}" if options[:for]
    if options[:time_start] && options[:time_end]
      results = DulyNoted.redis.zrevrangebyscore(key, options[:time_start].to_f, options[:time_end].to_f).collect do |metric|
        DulyNoted.redis.hgetall metric
      end
    else
      results = DulyNoted.redis.zrevrange(key, 0, -1).collect do |metric|
        DulyNoted.redis.hgetall metric
      end
    end
    return results
  end
  
  # ##Count
  # 
  # _parameters: `metric_name`, `for`(required if set when created), `time_start`(optional), `time_end`(optional)_
  # 
  # Count will return the number of events logged in a given time range, or if no time range is given, the total count.
  # 
  # `metric_name`: The name of the metric to query, ex: `page_views`, `downloads`
  # 
  # `for`_(required if you set `for` when you generated the metric)_: A name space for your metric, ex: `home_page`
  # 
  # `time_start`_(optional)_: The start of the time range to grab the data from.
  # 
  # `time_end`_(optional)_: The end of the time range to grab the data from.
  #
  # `time_range _(optional)_: Alternatively you can specify a time range, instead of `time_start` and `time_end`.
  # 
  # ###Usage
  # 
  #     DulyNoted.count("page_views",
  #       for: "home_page",
  #       time_start: Time.now,
  #       time_end: 1.day.ago)
  #
  #
  #     DulyNoted.count("page_views",
  #        for: "home_page",
  #        time_range: Time.now..1.day.ago)
  
  def count(metric_name, options={})
    key = normalize(metric_name)
    key << ":#{options[:for]}" if options[:for]
    if options[:time_range]
      options[:time_start] = options[:time_range].first
      options[:time_end] = options[:time_range].last
    end
    if options[:time_start] && options[:time_end]
      return DulyNoted.redis.zcount(key, options[:time_start].to_f, options[:time_end].to_f)
    else 
      return DulyNoted.redis.zcard(key)
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

      Redis.new({
        :host => url.host,
        :port => url.port,
        :db => url.path[1..-1],
        :password => url.password
      })
    )
  end
  
  private
  
  def normalize(str)
    str.downcase.gsub(/[^a-z0-9 ]/i, '').strip
  end
end
