module DulyNoted
  module Helpers
    
    def build_key(str, validity_test=true)
      if validity_test
        raise NotValidMetric if !valid_metric?(str) && !(caller[0] =~ /track/)
      end
      return "dn:" + normalize(str)
    end

    def normalize(str)
      if str.is_a?(Symbol)
        str = str.to_s
      end
      str.gsub(/[^a-z0-9 =]/i, '').strip
    end

    def assemble_for(options)
      case
      when options[:for].is_a?(String)
        ":#{normalize(options[:for])}"
      when options[:for].is_a?(Array)
        ":" << options[:for].collect{ |x| normalize(x) }.join(":")
      else
        ""
      end
    end

    # Attention: this is a rather slow implementation using "KEYS" command. Perhaps we should use sets?
    def find_keys(key, redis=nil)
      redis ||= DulyNoted.redis
      keys = []
      keys += redis.keys("#{key}:*")
      keys += redis.keys("#{key}")
      keys -= redis.keys("#{key}:*:meta")
      keys -= redis.keys("#{key}:ref:*")
      keys -= redis.keys("#{key}:*fields")
    end

    def parse_time_range(options)
      if options[:time_range]
        options[:time_start] = options[:time_range].first
        options[:time_end] = options[:time_range].last
      end
    end

    def metrics
      DulyNoted.redis.smembers build_key("metrics", false)
    end

    def valid_metric?(metric_name)
      DulyNoted.redis.sismember build_key("metrics", false), build_key(metric_name, false)
    end

    def fields_for(metric_name, options={})
      key = build_key(metric_name)
      key << assemble_for(options)
      keys = find_keys(key)
      fields = []
      keys.each do |key|
        fields += DulyNoted.redis.smembers("#{key}:fields")
      end
      fields
    end
  end
end