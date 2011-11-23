require "redis"
require "uri"
require "duly_noted/helpers"
require "duly_noted/version"

module DulyNoted
  extend self
    
  def track(metric_name, options={})
    options = {generated_at: Time.now}.merge(options)
    key = normalize(metric_name)
    key << ":#{options[:for]}" if options[:for]
    DulyNoted.redis.zadd key, options[:generated_at].to_f, "#{key}:#{options[:generated_at].to_f}:meta"
    DulyNoted.redis.set "#{normalize(metric_name)}:#{options[:for]}:#{options[:ref_id]}", key if options[:ref_id] # set alias key
    DulyNoted.redis.mapped_hmset "#{key}:#{options[:generated_at].to_f}:meta", options[:meta] if options[:meta] # set meta data
  end
  
  def update(metric_name, ref_id, options={})
    key = normalize(metric_name)
    key << ":#{options[:for]}" if options[:for]
    key << ":#{ref_id}"
    real_key = DulyNoted.redis.get key
    DulyNoted.redis.mapped_hmset real_key, options[:meta] if options[:meta] 
  end
  
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
  
  def count(metric_name, options={})
    key = normalize(metric_name)
    key << ":#{options[:for]}" if options[:for]
    if options[:time_start] && options[:time_end]
      return DulyNoted.redis.zcount(key, options[:time_start].to_f, options[:time_end].to_f)
    else 
      return DulyNoted.redis.zcard(key)
    end
  end
  
  def redis=(url)
    @redis = nil
    @redis_url = url
    redis
  end

  def redis
    @redis ||= (
      url = URI(@redis_url || "redis://127.0.0.1:6379/0")

      ::Redis.new({
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
