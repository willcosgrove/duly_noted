module DulyNoted
  module Helpers
    def normalize(str)
      str.downcase.gsub(/[^a-z0-9 ]/i, '').strip
    end

    def parse_time_range(options)
      if options[:time_range]
        options[:time_start] = options[:time_range].first
        options[:time_end] = options[:time_range].last
      end
    end
  end
end