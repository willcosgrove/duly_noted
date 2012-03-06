module DulyNoted
  module Helpers
    def normalize(str, validity_test=true)
      if validity_test
        raise NotValidMetric if !valid_metric?(str) && !(caller[0] =~ /track/)
      end
      return "dn:" + str.downcase.gsub(/[^a-z0-9 ]/i, '').strip
    end

    def parse_time_range(options)
      if options[:time_range]
        options[:time_start] = options[:time_range].first
        options[:time_end] = options[:time_range].last
      end
    end
  end
end