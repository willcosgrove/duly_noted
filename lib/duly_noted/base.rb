module DulyNoted
  class Base
    include Helpers
    
    def track(metric_name, options={})
      options = {generated_at: Time.now}.merge(options)
      key = normalize(metric_name)
      key << ":#{options[:for]}" if options[:for]
      redis.zadd key, options[:generated_at].to_f, "#{key}:#{options[:generated_at].to_f}:meta"
      redis.set "#{normalize(metric_name)}:#{options[:for]}:#{options[:ref_id]}", key if options[:ref_id] # set alias key
      redis.hmset "#{key}:#{options[:generated_at].to_f}:meta", options[:meta] if options[:meta] # set meta data
    end
    
    def update(metric_name, ref_id, options={})
      key = normalize(metric_name)
      key << ":#{options[:for]}" if options[:for]
      key << ":#{ref_id}"
      real_key = redis.get key
      redis.hmset real_key, options[:meta] if options[:meta] 
    end
    
    def query(metric_name, options={})
      key = normalize(metric_name)
      key << options[:for] if options[:for]
      if options[:time_start] && options[:time_end]
        results = redis.zrevrangebyscore(key, options[:time_start].to_f, options[:time_end].to_f).collect do |metric|
          redis.hgetall metric
        end
      else
        results = redis.zrevrange(key, 0, -1).collect do |metric|
          redis.hgetall metric
        end
      end
      return results
    end
    
    def count(metric_name, options={})
      key = normalize(metric_name)
      key << options[:for] if options[:for]
      if options[:time_start] && options[:time_end]
        return redis.zcount(key, options[:time_start].to_f, options[:time_end].to_f)
      else
        return redis.zcard(key)
      end
    end
    
  end
end