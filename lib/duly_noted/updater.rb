require "duly_noted/version"
require "duly_noted/helpers"
require "duly_noted/configuration"

module DulyNoted
  module Updater
    def update_schema(schema_version, redis)
      time = Time.now
      if schema_version === ["1","0","0"]
        #update to 1.0.1
        puts "Updating schema to comply with duly_noted 1.0.1"
        metrics = redis.smembers "dn:metrics"
        metrics.each do |metric|
          keys = find_keys(metric, redis)
          keys.each do |key|
            events = redis.zrange key, 0, -1
            events.each do |event|
              id = redis.incr "dnid"
              redis.zadd(key, redis.zscore(key, event), event.gsub(/:\d{10}.\d+:/, ":#{id}:"))
              redis.set("dnid:#{id}", "#{key}:#{id}:meta")
              if(redis.exists(event))
                redis.mapped_hmset "#{key}:#{id}:meta", redis.hgetall(event)
                redis.del(event)
              end
              redis.zrem(key, event)
            end
          end
        end
        redis.keys("*:ref:*").each do |ref_keys|
          redis.del(ref_keys)
        end
        schema_version = ["1","0","1"]
      end
      if schema_version === ["1","0","1"]
        #update to 1.0.2
        puts "Updating schema to comply with duly_noted 1.0.2"
        redis.keys("dnid:*").each do |id_key|
          redis.expire id_key, Configuration.editable_for
        end
        schema_version = ["1","0","2"]
      end
      redis.set "dn:version", VERSION
      puts "All up to date.  Completed updates in #{Time.now-time} seconds."
      return true
    end

    def check_schema(redis)
      schema_version = redis.get "dn:version"
      if !schema_version.nil?
        schema_version = schema_version.split(".")
        current_version = VERSION.split(".")
        if schema_version != current_version
          if update_schema(schema_version, redis)
            check_schema(redis)
          else
            raise UpdateError
          end
        end
      end
      redis.set "dn:version", VERSION
      return redis
    end
  end
end